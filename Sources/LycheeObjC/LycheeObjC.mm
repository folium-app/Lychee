//
//  LycheeObjC.m
//  Lychee
//
//  Created by Jarrod Norwell on 26/11/2024.
//

#import "LycheeObjC.h"

#include <SDL.h>

#include "lychee/frontend/config.h"
#include "lychee/psx.h"
#include "lychee/dev/cdrom/cdrom.h"

#include <algorithm>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

size_t findSystemCnf(std::ifstream& file, size_t startOffset, size_t maxReadSize) {
    std::vector<char> buffer(maxReadSize);
    file.seekg(startOffset);
    file.read(buffer.data(), maxReadSize);
    std::string content(buffer.begin(), buffer.end());
    return content.find("SYSTEM.CNF");
}

std::string getGameIDForLychee(const std::string& binFilePath) {
    const int blockSize = 1024 * 1024; // Read in 1MB blocks
    std::ifstream binFile(binFilePath, std::ios::binary);
    if (!binFile.is_open()) {
        throw std::runtime_error("Failed to open the .bin file");
    }

    binFile.seekg(0, std::ios::end);
    size_t fileSize = binFile.tellg();
    binFile.seekg(0, std::ios::beg);

    std::vector<char> buffer(blockSize);
    size_t bytesRead = 0;

    while (bytesRead < fileSize) {
        size_t readSize = std::min(blockSize, (int)(fileSize - bytesRead));
        binFile.read(buffer.data(), readSize);

        std::string content(buffer.begin(), buffer.begin() + readSize);
        size_t bootPos = content.find("BOOT");

        if (bootPos != std::string::npos) {
            // Extract the game ID
            size_t start = content.find("cdrom:", bootPos) + 7;
            size_t end = content.find(';', start);

            if (start == std::string::npos || end == std::string::npos) {
                throw std::runtime_error("Invalid BOOT line format");
            }

            return content.substr(start, end - start);
        }

        bytesRead += readSize;
    }

    throw std::runtime_error("BOOT line not found in the file");
}

void audio_update(void* ud, uint8_t* buf, int size) {
    psx_cdrom_t* cdrom = ((psx_t*)ud)->cdrom;
    psx_spu_t* spu = ((psx_t*)ud)->spu;

    memset(buf, 0, size);
    if (size <= 0)
        return;
    
    psx_cdrom_get_audio_samples(cdrom, buf, size);
    psx_spu_update_cdda_buffer(spu, cdrom->cdda_buf);

    for (int i = 0; i < (size >> 2); i++) {
        uint32_t sample = psx_spu_get_sample(spu);

        int16_t left = (int16_t)(sample & 0xffff);
        int16_t right = (int16_t)(sample >> 16);

        *(int16_t*)(&buf[(i << 2) + 0]) += left;
        *(int16_t*)(&buf[(i << 2) + 2]) += right;
    }
}

psx_t* psx = nullptr;
uint32_t mode = 0, width = 0, height = 0;
SDL_AudioDeviceID dev;

uint32_t screen_get_base_width(psx_t* psx) {
    int width = psx_get_dmode_width(psx);

    switch (width) {
        case 256: return 256;
        case 320: return 320;
        case 368: return 384;
    }

    return 320;
}

void psxe_gpu_dmode_event_cb(psx_gpu_t* gpu) {
    mode = psx_get_display_format(psx) ? 1 : 0;
    
    width = screen_get_base_width(psx);
    height = 240;
}

void psxe_gpu_vblank_event_cb(psx_gpu_t* gpu) {
    auto dWidth = psx_get_display_width(psx);
    auto dHeight = psx_get_display_height(psx);
    
    if (mode == 1) {
        std::vector<uint8_t> data(PSX_GPU_FB_HEIGHT * PSX_GPU_FB_WIDTH * 3);
        
        // 24-bit
        if (auto buffer = [[LycheeObjC sharedInstance] rgb888]) {
            auto vram = static_cast<uint16_t*>(psx_get_display_buffer(psx));
            for (int y = 0; y < PSX_GPU_FB_HEIGHT; y++) {
                unsigned int gpuOffset = y * PSX_GPU_FB_WIDTH;
                unsigned int texOffset = y * PSX_GPU_FB_WIDTH * 3;
                for (int x = 0; x < PSX_GPU_FB_WIDTH; x += 3) {
                    uint16_t c1 = vram[gpuOffset + 0];
                    uint16_t c2 = vram[gpuOffset + 1];
                    uint16_t c3 = vram[gpuOffset + 2];
                    
                    uint8_t r0 = (c1 & 0x00ff) >> 0;
                    uint8_t g0 = (c1 & 0xff00) >> 8;
                    uint8_t b0 = (c2 & 0x00ff) >> 0;
                    uint8_t r1 = (c2 & 0xff00) >> 8;
                    uint8_t g1 = (c3 & 0x00ff) >> 0;
                    uint8_t b1 = (c3 & 0xff00) >> 8;
                    
                    data.at(texOffset + 0) = r0;
                    data.at(texOffset + 1) = g0;
                    data.at(texOffset + 2) = b0;
                    data.at(texOffset + 3) = r1;
                    data.at(texOffset + 4) = g1;
                    data.at(texOffset + 5) = b1;
                    
                    gpuOffset += 3;
                    texOffset += 6;
                }
            }
            
            buffer(data.data(), dWidth, dHeight, width, height);
        }
    } else {
        // 15-bit
        if (auto buffer = [[LycheeObjC sharedInstance] bgr555])
            buffer(psx_get_display_buffer(psx), dWidth, dHeight, width, height);
    }
    
    psxe_gpu_vblank_timer_event_cb(gpu);
}

@implementation LycheeObjC
+(LycheeObjC *) sharedInstance {
    static LycheeObjC *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) insert:(NSURL *)url {
    psxe_config_t* cfg = psxe_cfg_create();

    NSURL *lycheeDirectoryURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject] URLByAppendingPathComponent:@"Lychee"];
    
    psxe_cfg_init(cfg);
    psxe_cfg_load_defaults(cfg);
    cfg->bios = [[[lycheeDirectoryURL URLByAppendingPathComponent:@"sysdata"] URLByAppendingPathComponent:@"bios.bin"].path UTF8String];
    cfg->use_args = 1;
    // cfg->cd_path = [url.path UTF8String];

    if ([url.pathExtension isEqualToString:@"exe"])
        cfg->exe = [url.path UTF8String];
    else
        cfg->cd_path = [url.path UTF8String];
    
    log_set_level(cfg->log_level);

    psx = psx_create();
    psx_init(psx, cfg->bios, cfg->exp_path);

    psx_cdrom_t* cdrom = psx_get_cdrom(psx);

    if (cfg->cd_path)
        psx_cdrom_open(cdrom, cfg->cd_path);
    
    SDL_SetMainReady();
    SDL_Init(SDL_INIT_AUDIO);
    
    SDL_AudioSpec obtained, desired;

    desired.freq     = 44100;
    desired.format   = AUDIO_S16SYS;
    desired.channels = 2;
    desired.samples  = CD_SECTOR_SIZE >> 2;
    desired.callback = &audio_update;
    desired.userdata = psx;

    dev = SDL_OpenAudioDevice(NULL, 0, &desired, &obtained, 0);

    if (dev)
        SDL_PauseAudioDevice(dev, 0);
    
    psx_gpu_t* gpu = psx_get_gpu(psx);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_DMODE, psxe_gpu_dmode_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_VBLANK, psxe_gpu_vblank_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_HBLANK, psxe_gpu_hblank_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_VBLANK_END, psxe_gpu_vblank_end_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_HBLANK_END, psxe_gpu_hblank_end_event_cb);
    // psx_gpu_set_udata(gpu, 0, screen);
    psx_gpu_set_udata(gpu, 1, psx->timer);

    psx_input_t* input = psx_input_create();
    psx_input_init(input);

    // psxi_guncon_t* controller = psxi_guncon_create();
    // psxi_guncon_init(controller);
    // psxi_guncon_init_input(controller, input);
    psxi_sda_t* controller = psxi_sda_create();
    psxi_sda_init(controller, SDA_MODEL_DIGITAL);
    psxi_sda_init_input(controller, input);

    psx_pad_attach_joy(psx->pad, 0, input);
    psx_pad_attach_mcd(psx->pad, 0, [[[lycheeDirectoryURL URLByAppendingPathComponent:@"memcards"] URLByAppendingPathComponent:@"mc1.mcd"].path UTF8String]);
    psx_pad_attach_mcd(psx->pad, 1, [[[lycheeDirectoryURL URLByAppendingPathComponent:@"memcards"] URLByAppendingPathComponent:@"mc2.mcd"].path UTF8String]);

    if (cfg->exe) {
        while (psx->cpu->pc != 0x80030000)
            psx_update(psx);

        psx_load_exe(psx, cfg->exe);
    }

    psxe_cfg_destroy(cfg);
}

-(void) step {
    psx_update(psx);
}

-(void) stop {
    SDL_PauseAudioDevice(dev, 1);
    SDL_CloseAudioDevice(dev);
    
    psx_destroy(psx);
}

-(void) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed {
    if (pressed)
        psx_pad_button_press(psx_get_pad(psx), slot, button);
    else
        psx_pad_button_release(psx_get_pad(psx), slot, button);
}

-(NSString *) id:(NSURL *)url {
    NSString *string = @"";
    try {
        string = [NSString stringWithCString:getGameIDForLychee([url.path UTF8String]).c_str() encoding:NSUTF8StringEncoding];
    } catch (std::runtime_error& e) {
        NSLog(@"%@", [NSString stringWithCString:e.what() encoding:NSUTF8StringEncoding]);
        string = @"";
    }
    
    return string;
}
@end
