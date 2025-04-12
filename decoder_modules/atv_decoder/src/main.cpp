#include <config.h>
#include <core.h>
#include <filesystem>
#include <gui/gui.h>
#include <gui/style.h>
#include <gui/widgets/image.h>
#include <imgui.h>
#include <module.h>
#include <signal_path/signal_path.h>

#include <dsp/demod/quadrature.h>
#include <dsp/sink/handler_sink.h>
#include "linesync.h"
#include <dsp/loop/pll.h>
#include <dsp/convert/real_to_complex.h>
#include <dsp/filter/fir.h>
#include <dsp/taps/from_array.h>

#include "chrominance_filter.h"

#include "chroma_pll.h"

#include "linesync_old.h"
#include "amplitude.h"
#include <dsp/demod/am.h>
#include <dsp/loop/fast_agc.h>

#define CONCAT(a, b) ((std::string(a) + b).c_str())

SDRPP_MOD_INFO{/* Name:            */ "atv_decoder",
               /* Description:     */ "ATV decoder for SDR++",
               /* Author:          */ "Ryzerth",
               /* Version:         */ 0, 1, 0,
               /* Max instances    */ -1
};

#define SAMPLE_RATE (625.0f * (float)LINE_SIZE * 25.0f)

class ATVDecoderModule : public ModuleManager::Instance {
  public:
    ATVDecoderModule(std::string name) : img(768, 576) {
        this->name = name;

        vfo = sigpath::vfoManager.createVFO(name, ImGui::WaterfallVFO::REF_CENTER, 0, 7000000.0f, SAMPLE_RATE, SAMPLE_RATE, SAMPLE_RATE, true);

        agc.init(vfo->output, 1.0f, 1e6, 0.001f, 1.0f);
        demod.init(&agc.out, SAMPLE_RATE, SAMPLE_RATE / 2.0f);
        //demod.init(vfo->output, dsp::demod::AM<float>::CARRIER, 8000000.0f, 50.0 / SAMPLE_RATE, 50.0 / SAMPLE_RATE, 0.0f, SAMPLE_RATE);
        sync.init(&demod.out, 1.0f, 1e-6, 1.0, 0.05);
        sink.init(&sync.out, handler, this);

        r2c.init(NULL);

        agc.start();
        demod.start();
        sync.start();
        sink.start();

        gui::menu.registerEntry(name, menuHandler, this, this);
    }

    ~ATVDecoderModule() {
        if (vfo) {
            sigpath::vfoManager.deleteVFO(vfo);
        }
        agc.stop();
        demod.stop();
        sync.stop();
        sink.stop();
        gui::menu.removeEntry(name);
    }

    void postInit() {}

    void enable() {
        enabled = true;
    }

    void disable() {
        enabled = false;
    }

    bool isEnabled() { return enabled; }

  private:
    static void menuHandler(void *ctx) {
        ATVDecoderModule *_this = (ATVDecoderModule *)ctx;

        if (!_this->enabled) {
            style::beginDisabled();
        }

        ImGui::FillWidth();
        _this->img.draw();

        ImGui::TextUnformatted("Horizontal Sync:");
        ImGui::SameLine();
        if (_this->sync.locked > 750) {
            ImGui::TextColored(ImVec4(0, 1, 0, 1), "Locked");
        }
        else {
            ImGui::TextUnformatted("Not locked");
        }

        ImGui::TextUnformatted("Vertical Sync:");
        ImGui::SameLine();
        if (_this->vlock > 15) {
            ImGui::TextColored(ImVec4(0, 1, 0, 1), "Locked");
        }
        else {
            ImGui::TextUnformatted("Not locked");
        }

        ImGui::Checkbox("Fast Lock", &_this->sync.fastLock);
        ImGui::Checkbox("Color Mode", &_this->colorMode);

        if (!_this->enabled) {
            style::endDisabled();
        }

        ImGui::Text("Gain: %f", _this->gain);
        ImGui::Text("Offset: %f", _this->offset);
    }

    static void handler(float *data, int count, void *ctx) {
        ATVDecoderModule *_this = (ATVDecoderModule *)ctx;

        // Correct the offset
        volk_32f_s32f_add_32f(data, data, _this->offset, count);

        // Correct the gain
        volk_32f_s32f_multiply_32f(data, data, _this->gain, count);

        // Compute the sync levels
        float syncLLevel = 0.0f;
        float syncRLevel = 0.0f;
        volk_32f_accumulator_s32f(&syncLLevel, data, EQUAL_LEN);
        volk_32f_accumulator_s32f(&syncRLevel, &data[EQUAL_LEN], SYNC_LEN - EQUAL_LEN);
        syncLLevel *= 1.0f / EQUAL_LEN;
        syncRLevel *= 1.0f / (SYNC_LEN - EQUAL_LEN);
        float syncLevel = (syncLLevel + syncRLevel) * 0.5f; // TODO: It's technically correct but if the sizes were different it wouldn't be

        // Compute the blanking level
        float blankLevel = 0.0f;
        volk_32f_accumulator_s32f(&blankLevel, &data[HBLANK_START], HBLANK_LEN);
        blankLevel /= (float)HBLANK_LEN;

        // Run the offset control loop
        _this->offset -= (blankLevel / _this->gain)*0.001;
        _this->offset = std::clamp<float>(_this->offset, -1.0f, 1.0f);
        _this->gain -= (blankLevel - syncLevel + SYNC_LEVEL)*0.01f;
        _this->gain = std::clamp<float>(_this->gain, 0.1f, 10.0f);

        // Detect the sync type
        uint16_t shortSync = (syncLLevel < 0.5f*SYNC_LEVEL) && (syncRLevel > 0.5f*SYNC_LEVEL) && (blankLevel > 0.5f*SYNC_LEVEL);
        uint16_t longSync = (syncLLevel < 0.5f*SYNC_LEVEL) && (syncRLevel < 0.5f*SYNC_LEVEL) && (blankLevel < 0.5f*SYNC_LEVEL);

        // Save sync type to history
        _this->syncHistory = (_this->syncHistory << 2) | (longSync << 1) | shortSync;

        // Render the line if it's visible
        if (_this->ypos >= 34 && _this->ypos <= 34+576-1) {
            uint32_t* currentLine = &((uint32_t *)_this->img.buffer)[(_this->ypos - 34)*768];
            for (int i = 155; i < (155+768); i++) {
                int imval = std::clamp<float>(data[i] * 255.0f, 0, 255);
                currentLine[i-155] = 0xFF000000 | (imval << 16) | (imval << 8) | imval;
            }
        }

        // Compute whether to rollover
        bool rollToOdd = (_this->ypos == 624);
        bool rollToEven = (_this->ypos == 623);

        // Compute the field sync
        bool syncToOdd = (_this->syncHistory == 0b0101011010010101);
        bool syncToEven = (_this->syncHistory == 0b0001011010100101);

        // Process the sync (NOTE: should start with 0b01, but for some reason I don't see a sync?)
        if (rollToOdd || syncToOdd) {
            // Update the vertical lock state
            bool disagree = (rollToOdd ^ syncToOdd);
            if (disagree && _this->vlock > 0) {
                _this->vlock--;
            }
            else if (!disagree && _this->vlock < 20) {
                _this->vlock++;
            }

            // Start the odd field
            _this->ypos = 1;
        }
        else if (rollToEven || syncToEven) {
            // Update the vertical lock state
            bool disagree = (rollToEven ^ syncToEven);
            if (disagree && _this->vlock > 0) {
                _this->vlock--;
            }
            else if (!disagree && _this->vlock < 20) {
                _this->vlock++;
            }

            // Start the even field
            _this->ypos = 0;

            // Swap the video buffer
            _this->img.swap();
        }
        else {
            _this->ypos += 2;
        }
    }

    // NEW SYNC:
    float offset = 0.0f;
    float gain = 1.0f;
    uint16_t syncHistory = 0;
    int ypos = 0;
    int vlock = 0;

    std::string name;
    bool enabled = true;

    VFOManager::VFO *vfo = NULL;
    //dsp::demod::Quadrature demod;
    dsp::loop::FastAGC<dsp::complex_t> agc;
    dsp::demod::Amplitude demod;
    //dsp::demod::AM<float> demod;
    LineSync sync;
    dsp::sink::Handler<float> sink;
    dsp::convert::RealToComplex r2c;

    bool colorMode = false;

    ImGui::ImageDisplay img;
};

MOD_EXPORT void _INIT_() {}

MOD_EXPORT ModuleManager::Instance *_CREATE_INSTANCE_(std::string name) { return new ATVDecoderModule(name); }

MOD_EXPORT void _DELETE_INSTANCE_(void *instance) { delete (ATVDecoderModule *)instance; }

MOD_EXPORT void _END_() {}