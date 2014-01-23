//
//  FLVPacket.h
//  PresentRTMPStreamModule
//
//  Created by Justin Makaila on 7/20/13.
//  Copyright (c) 2013 Present, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <librtmp/amf.h>

// H264 Constant
#define MAX_H264_FRAMESIZE 131072

//Offsets
#define FLV_AUDIO_SAMPLESIZE_OFFSET 1
#define FLV_AUDIO_SAMPLERATE_OFFSET 2
#define FLV_AUDIO_CODECID_OFFSET    4

#define FLV_VIDEO_FRAMETYPE_OFFSET  4

// Bitmasks to isolate specific values
#define FLV_AUDIO_CHANNEL_MASK      0x01
#define FLV_AUDIO_SAMPLESIZE_MASK   0x02
#define FLV_AUDIO_SAMPLERATE_MASK   0x0c
#define FLV_AUDIO_CODEC_ID_MASK     0xf0

#define FLV_VIDEO_CODECID_MASK      0x0f
#define FLV_VIDEO_FRAMETYPE_MASK    0xf0

#define AMF_END_OF_OBJECT           0x09

enum {
    FLV_HEADER_FLAG_HASVIDEO    = 1,
    FLV_HEADER_FLAG_HASAUDIO    = 4,
};

enum {
    FLV_TAG_TYPE_AUDIO          = 0x08,
    FLV_TAG_TYPE_VIDEO          = 0x09,
    FLV_TAG_TYPE_META           = 0x12,
};

enum {
    FLV_MONO                    = 0,
    FLV_STEREO                  = 1,
};

enum {
    FLV_SAMPLESIZE_8BIT         = 0,
    FLV_SAMPLESIZE_16BIT        = 1 << FLV_AUDIO_SAMPLESIZE_OFFSET
};

enum {
    FLV_SAMPLERATE_SPECIAL      = 0,
    FLV_SAMPLERATE_11025HZ      = 1 << FLV_AUDIO_SAMPLERATE_OFFSET,
    FLV_SAMPLERATE_22050HZ      = 2 << FLV_AUDIO_SAMPLERATE_OFFSET,
    FLV_SAMPLERATE_44100HZ      = 3 << FLV_AUDIO_SAMPLERATE_OFFSET,
};

enum {
    FLV_CODECID_PCM                     = 0,
    FLV_CODECID_ADPCM                   = 1 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_MP3                     = 2 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_PCM_LE                  = 3 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_NELLYMOSER_16KHZ_MONO   = 4 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_NELLYMOSER_8KHZ_MONO    = 5 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_NELLYMOSER              = 6 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_PCM_ALAW                = 7 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_PCM_MULAW               = 8 << FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_AAC                     = 10<< FLV_AUDIO_CODECID_OFFSET,
    FLV_CODECID_SPEEX                   = 11<< FLV_AUDIO_CODECID_OFFSET,
};

enum {
    FLV_CODECID_H263            = 2,
    FLV_CODECID_SCREEN          = 3,
    FLV_CODECID_VP6             = 4,
    FLV_CODECID_VP6A            = 5,
    FLV_CODECID_SCREEN2         = 6,
    FLV_CODECID_H264            = 7,
};

enum {
    FLV_FRAME_KEY               = 1 << FLV_VIDEO_FRAMETYPE_OFFSET,
    FLV_FRAME_INTER             = 2 << FLV_VIDEO_FRAMETYPE_OFFSET,
    FLV_FRAME_DISP_INTER        = 3 << FLV_VIDEO_FRAMETYPE_OFFSET,
};

typedef struct FLVContext {
    int64_t duration_offset;
    int64_t filesize_offset;
    int64_t ts;
    int64_t ts_last;
    int64_t duration;
    int64_t delay;
} FLVContext;

@interface FLVPacket : NSObject
/*
 *  Type:   Instance Method
 *  Usage:  [[FLVPacket alloc]init]
 *  Desc:   Initializes and returns an instance of
 *          FLVPacket
 * ------------------------------------------------
 */
- (id)init;

/*
 *  Type:   Instance Method
 *  Usage:  [FLVPacket writeStreamHeader:buffer]
 *  Desc:   Writes all stream metadata to the supplied buffer
 * ----------------------------------------------------------
 *  Parameters:
 *    uint8_t* buffer:  the buffer to write the metadata to
 *
 *  Return Value:
 *    int bufferSize:   the size of the metadata written to
 *                      the buffer
 */
- (int)writeStreamHeader:(uint8_t**)buffer ofSize:(int)bufferSize withAvcC:(NSData*)avcC ofSize:(int)avcCSize;

/*
 *  Type:   Instance Method
 *  Usage:  [FLVPacket writeAvcCHeader:avcC toBuffer:buffer]
 *  Desc:   Writes the SPS and PPS data to the supplied buffer
 * -----------------------------------------------------------
 *  Parameters:
 *    NSData*  avcC:    the avcC data to write to the buffer
 *    uint8_t* buffer:  the buffer to write the metadata to
 *
 *  Return Value:
 *    int bufferSize:   the size of the metadata written to
 *                      the buffer
 */
- (int)writeAvcCHeader:(NSData*)avcC toBuffer:(uint8_t**)buffer;

/*
 *  Type:   Instance Method
 *  Usage:  [FLVPacket writeNALU:nalu toPacket:packet time:pts keyframe:keyframe]
 *  Desc:   Writes the header and NALU payload to supplied packet
 * ------------------------------------------------------------------------------
 *  Parameters:
 *    uint8_t* nalu:    the NALU data to write to the packet
 *    uint8_t* buffer:  the buffer to write the data to
 *    double pts:       the presentation time stamp
 *    BOOL isKeyframe:  flag indicating whether this frame is a keyframe
 *
 *  Return Value:
 *    int bufferSize:   the size of the packet
 */
- (int)writeNALU:(uint8_t*)nalu ofSize:(int)naluSize toPacket:(uint8_t**)packet time:(double)pts keyframe:(BOOL)isKeyframe;

- (int)writeAAC:(uint8_t*)aacData ofSize:(int)aacSize toPacket:(uint8_t**)packet time:(double)pts;

/*
 *  Type:   Instance Method
 *  Usage:  [FLVPacket writeStreamTrailer:buffer]
 *  Desc:   Writes the stream trailer to supplied buffer, 
            updating duration and filesize metadata
 * ------------------------------------------------------
 *  Parameters:
 *    uint8_t* buffer: the buffer to write the data to
 *
 *  Return Value:
 *    int bufferSize: the size of the packet
 */
- (int)writeStreamTrailer:(uint8_t**)buffer time:(unsigned)pts;

@end
