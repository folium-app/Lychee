//
//  bridge.cpp
//  Lychee
//
//  Created by Jarrod Norwell on 2/7/2026.
//

#include "bridge.h"
#include "mesence.h"

#include "Shared/EmuSettings.h"
#include "Shared/MessageManager.h"
#include "Shared/SaveStateManager.h"
#include "Utilities/FolderUtilities.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <mutex>
#include <thread>

#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "Lychee-Swift.h"
using namespace Lychee;

struct cntnr_l {
    LycheeCommon lycheeCommon{LycheeCommon::init()};
    LycheeSystem lycheeSystem{LycheeSystem::init()};
    
    std::unique_ptr<Emulator> emulator;
    std::unique_ptr<SNESInput> input;
    std::unique_ptr<iOSRenderer> renderer;
    std::unique_ptr<iOSSink> sink;
    
    std::condition_variable_any cv;
    std::mutex mutex;
    std::atomic<bool> paused, running;
    std::jthread thread;
    
    uint32_t height, width;
    
    std::filesystem::path lychee_path, debugger_path, firmware_path;
    std::filesystem::path hd_packs_path, recent_games_path, saves_path;
    std::filesystem::path save_states_path, screenshots_path, system_data_path;
} cntnr_l;

void lychee::print_about(void) {
    printf("Welcome to Lychee\n");
    printf("Super Nintendo Entertainment System emulation provided by MesenCE\n");
}

void lychee::initialize_paths(void) {
    auto lycheeDirectoryURL{cntnr_l.lycheeCommon.getLycheeDirectoryURL()};
    if (lycheeDirectoryURL.isSome()) {
        auto lychee_path{std::filesystem::path{lycheeDirectoryURL.get()}};
        
        cntnr_l.lychee_path = lychee_path;
        cntnr_l.debugger_path = lychee_path / "debugger";
        cntnr_l.firmware_path = lychee_path / "firmware";
        cntnr_l.hd_packs_path = lychee_path / "hd_packs";
        cntnr_l.recent_games_path = lychee_path / "recent_games";
        cntnr_l.saves_path = lychee_path / "saves";
        cntnr_l.save_states_path = lychee_path / "save_states";
        cntnr_l.screenshots_path = lychee_path / "screenshots";
        cntnr_l.system_data_path = lychee_path / "system_data";
    }
}

void lychee::initialize_system(void) {
    auto mm{std::make_unique<iOSMessageManager>()};
    MessageManager::SetOptions(false, true);
    MessageManager::RegisterMessageManager(mm.get());
    
    cntnr_l.emulator = std::make_unique<Emulator>();
    cntnr_l.emulator->Initialize(false);
    
    cntnr_l.input = std::make_unique<SNESInput>();
    cntnr_l.renderer = std::make_unique<iOSRenderer>(cntnr_l.emulator, 224, 256);
    cntnr_l.sink = std::make_unique<iOSSink>(cntnr_l.emulator, 48000);
    
    SnesConfig snes = cntnr_l.emulator->GetSettings()->GetSnesConfig();
    for (int i = 0; i < sizeof(snes.ChannelVolumes) / sizeof(snes.ChannelVolumes[0]); i++)
        snes.ChannelVolumes[i] = 100;
    snes.Overscan.Top = snes::kSnesOverscanTop;
    snes.Overscan.Bottom = snes::kSnesOverscanBottom;
    snes.Port1.Type = ControllerType::SnesController;
    cntnr_l.emulator->GetSettings()->SetSnesConfig(snes);
}


void lychee::destroy_system(void) {
    lychee::initialize_system();
}


void lychee::insert_disc(std::string path) {
    FolderUtilities::SetHomeFolder(cntnr_l.lychee_path.string());
    FolderUtilities::SetFolderOverrides({}, {}, {}, cntnr_l.system_data_path);
    
    cntnr_l.emulator->LoadRom({path}, {});
    cntnr_l.emulator->RegisterInputProvider(cntnr_l.input.get());
}


bool lychee::is_paused(bool change, bool set_paused) {
    if (change)
        cntnr_l.paused.store(set_paused);
    
    if (change)
        set_paused ? cntnr_l.emulator->Pause() : cntnr_l.emulator->Resume();
    
    if (change && !set_paused)
        cntnr_l.cv.notify_one();
    
    return cntnr_l.paused.load();
}

bool lychee::is_running(bool change, bool set_running) {
    if (change)
        cntnr_l.running.store(set_running);
    return cntnr_l.running.load();
}


void lychee::start(void) {
    cntnr_l.thread = std::jthread([&](std::stop_token token) {
        using namespace std::chrono;
        
        const auto frameDuration = duration<double>(1.0 / 60.0);
        
        while (!token.stop_requested()) {
            {
                std::unique_lock lock(cntnr_l.mutex);
                cntnr_l.cv.wait(lock, token, []() {
                    return !cntnr_l.paused.load();
                });
                
                if (token.stop_requested())
                    break;
            }
            
            auto frameStart = steady_clock::now();
            
            std::vector<uint32_t> data{0};
            if (cntnr_l.renderer->GetFrameIfReady(data, cntnr_l.height, cntnr_l.width))
                lychee::video_callback(lychee::context, data.data(), 0);

            // Limit FPS
            auto frameEnd = steady_clock::now();
            auto elapsed = frameEnd - frameStart;
            if (elapsed < frameDuration)
                std::this_thread::sleep_for(frameDuration - elapsed);
        }
    });
}

void lychee::stop(void) {
    cntnr_l.emulator->Stop(false, true);
    
    cntnr_l.thread.request_stop();
    if (cntnr_l.thread.joinable())
        cntnr_l.thread.join();
    
    cntnr_l.paused.store(false);
    cntnr_l.running.store(false);
}


int lychee::framebuffer_height(void) {
    return cntnr_l.height;
}

int lychee::framebuffer_width(void) {
    return cntnr_l.width;
}


void lychee::audio_buffer_callback(lychee::AudioVideoBufferCallback callback) {
    lychee::audio_callback = callback;
}

void lychee::video_buffer_callback(lychee::AudioVideoBufferCallback callback) {
    lychee::video_callback = callback;
}


void lychee::press_button(uint32_t button) {
    cntnr_l.input->keys |= button;
}

void lychee::release_button(uint32_t button) {
    cntnr_l.input->keys &= ~button;
}


void lychee::set_context(void* context) {
    lychee::context = context;
}


bool lychee::save_state_exists(int index) {
    if (const auto& save_state_manager = cntnr_l.emulator->GetSaveStateManager()) {
        const auto& path{save_state_manager->GetSaveStatePath(index)};
        return std::filesystem::exists(path) && std::filesystem::file_size(path) > 0;
    } return false;
}

std::string lychee::save_state_path(int index) {
    if (const auto& save_state_manager = cntnr_l.emulator->GetSaveStateManager()) {
        return save_state_manager->GetSaveStatePath(index);
    } return {};
}

void lychee::load_state(int index) {
    if (const auto& save_state_manager = cntnr_l.emulator->GetSaveStateManager())
        save_state_manager->LoadState(index);
}

void lychee::save_state(int index) {
    if (const auto& save_state_manager = cntnr_l.emulator->GetSaveStateManager())
        save_state_manager->SaveState(index);
}
