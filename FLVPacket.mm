//
//  FLVPacket.m
//  PresentRTMPStreamModule
//
//  Created by Justin Makaila on 7/20/13.
//  Copyright (c) 2013 Present, Inc. All rights reserved.
//

#import "FLVPacket.h"
#import "NALUnit.h"

#define STR2AVAL(av,str)        av.av_val = str; av.av_len = strlen(av.av_val)

#define VIDEO_WIDTH             320
#define VIDEO_HEIGHT            320
#define VIDEO_BITRATE           512000
#define VIDEO_FRAMERATE         30

#define METADATA_COUNT          12

// skip x bytes
void skip_bytes(uint8_t **data, uint8_t val) {
    *data += val;
}

// puts 8 bits
void put_byte(uint8_t **data, uint8_t val) {
    MLLog(@"***************** START of put_byte *****************");
    
    DLLog(@"Value = %i", val);
    
    assert(val >= -128 && val <= 255);
    *data[0]++ = val;
    
    DLLog(@"Value of data\n \t*data[0] = %p", (void*)*data[0]);
    DLLog(@"Value of data pointers\n \tdata = %p\n \t*data = %p\n \t*data[0] = %p", data, *data, (void*)*data[0]);
    MLLog(@"***************** END of put_byte *****************");
}

// puts 16 bits
void put_be16(uint8_t **data, unsigned int val) {
    MLLog(@"***************** START of put_be16 *****************");
    
    put_byte(data, (int)val >> 8);
    put_byte(data, (uint8_t)val);
    
    MLLog(@"***************** END of put_be16 *****************");
}

// puts 24 bits
void put_be24(uint8_t **data, unsigned int val) {
    MLLog(@"***************** START of put_be24 *****************");
    
    DLLog(@"Value = %i", val);
    put_be16(data, (int)val >> 8);
    put_byte(data, (uint8_t)val);
    
    MLLog(@"***************** END of put_be24 *****************");
}

// puts 32 bits
void put_be32(uint8_t **data, unsigned int val) {
    MLLog(@"***************** START of put_be32 *****************");
    
    DLLog(@"Value = %i", val);
    put_byte(data,           val >> 24);
    put_byte(data, (uint8_t)(val >> 16));
    put_byte(data, (uint8_t)(val >> 8));
    put_byte(data, (uint8_t) val);
    
    MLLog(@"***************** END of put_be32 *****************");
}

// puts buffer
void put_buff(uint8_t **data, const uint8_t *src, int32_t srcsize) {
    MLLog(@"***************** START of put_buff *****************");
    
    memcpy(*data, src, srcsize);
    *data += srcsize;
    
    MLLog(@"***************** END of put_buff *****************");
}

// puts 8 bit representation of each char
void put_tag(uint8_t **data, const char *tag) {
    MLLog(@"***************** START of put_tag *****************");
    
    while (*tag) {
        DLLog(@"\n\n \t *tag = %c", *tag);
        put_byte(data, *tag++);
    }
    
    MLLog(@"***************** END of put_tag *****************");
}

@implementation FLVPacket

-(id)init {
    self = [super init];
    return self;
}

- (int)writeStreamHeader:(uint8_t**)buffer ofSize:(int)bufferSize withAvcC:(NSData *)avcC ofSize:(int)avcCSize {
    uint8_t     *pStart             = *buffer;                              // Start address of supplied buffer
    char        *pEnd               = (char*)pStart + bufferSize;           // Start of buffer + bufferSize
    char        *enc                = NULL;                                 // Pointer to encode metadata
    AVal        av;                                                         // AVal used to encode metadata
    int64_t     dataSize            = 0;                                    // Size of the data written
    uint8_t     *metaDataSizePos;
    int64_t     sizePos;
    uint8_t     *ref;
    
    FLVLog(@"Checkpoint #%i: Start of method\n  \tbuffer = %p\n \t*buffer = %p\n \t**buffer = %p\n", kNumCheckpoint++, buffer, *buffer, (void*)**buffer);
    
    put_tag(buffer, "FLV");                                                // Tag type META
    put_byte(buffer, 1);                                                   // Reserved
    put_byte(buffer, FLV_HEADER_FLAG_HASVIDEO);                            // 1
    put_be32(buffer, 9);
    put_be32(buffer, 0);
    
#pragma mark - Metadata start
    put_byte(buffer, 18);                                                  // Tag type META
    metaDataSizePos = *buffer;                                             // Save the position of the metadata size
    put_be24(buffer, 0);                                                   // Size of data (sum of all metadata below)
    
    FLVLog(@"Checkpoint #%i\n  \tbuffer = %p\n \t*buffer = %p\n \t**buffer = %p\n\n  \tdataSize = %i", kNumCheckpoint++, buffer, *buffer, (void*)**buffer, *buffer - pStart);
    
    put_be24(buffer, 0);                                                   // Set first 3 bytes of timestamp field to 0
    put_byte(buffer, 0);                                                   // Timestamp extension
    put_be24(buffer, 0);                                                   // StreamID
    
    FLVLog(@"Checkpoint #%i\n  \tbuffer = %p\n  \t*buffer = %p\n  \t**buffer = %p\n\n  \tdataSize = %i", kNumCheckpoint++, buffer, *buffer, (void*)**buffer, *buffer - pStart);
    
    enc = (char*)(*buffer);
    
    FLVLog(@"Checkpoint #%i: Start of metadata\n  \t*buffer = %p \n  \t(char*)*buffer = %p\n\n  \tenc = %p", kNumCheckpoint++, *buffer, (char*)*buffer, enc);
    
    STR2AVAL(av, (char*)"onMetaData");
    enc = AMF_EncodeString(enc, pEnd, &av);                                 // 12 byte onMetaData string
    *enc++ = AMF_ECMA_ARRAY;                                                // Write that an array will follow
    enc = AMF_EncodeInt32(enc, pEnd, METADATA_COUNT);                       // Array length
    
    STR2AVAL(av, (char*)"duration");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, 0.0);                       // Duration (updated at the end of stream)
    
    STR2AVAL(av, (char*)"width");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, VIDEO_WIDTH);               // Width of the video stream
    
    STR2AVAL(av, (char*)"height");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, VIDEO_HEIGHT);              // Height of the video stream
    
    STR2AVAL(av, (char*)"videodatarate");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, (VIDEO_BITRATE / 1024.0));  // Video data rate
    
    STR2AVAL(av, (char*)"framerate");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, VIDEO_FRAMERATE);           // Video frame rate
    
    STR2AVAL(av, (char*)"videocodecid");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, FLV_CODECID_H264);          // Video codec id
    
    STR2AVAL(av, (char*)"audiodatarate");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, (64000 / 1024));
    
    STR2AVAL(av, (char*)"audiosamplerate");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, 44100);
    
    STR2AVAL(av, (char*)"audiosamplesize");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, 16);
    
    STR2AVAL(av, (char*)"stereo");
    enc = AMF_EncodeNamedBoolean(enc, pEnd, &av, 0);
    
    STR2AVAL(av, (char*)"audiocodecid");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, FLV_CODECID_AAC);
    
    STR2AVAL(av, (char*)"filesize");
    enc = AMF_EncodeNamedNumber(enc, pEnd, &av, 0.0);
    
    enc = AMF_EncodeInt16(enc, pEnd, 0);
    *enc++ = AMF_OBJECT_END;                                                // Mark the end of the array                                    0x09
    
    dataSize = enc - (char*)metaDataSizePos - 10;
    
    FLVLog(@"Checkpoint #%i: End of metadata\n\n  enc = %p\n  *enc = %p\n\n  buffer = %p\n  *buffer = %p\n\n  metaDataSizePos = %p\n  *metaDataSizePos = %p\n\n  dataSize = %llu", kNumCheckpoint++, enc, (void*)*enc, buffer, (void*)*buffer, metaDataSizePos, (void*)*metaDataSizePos, dataSize);
    
    put_be24(&metaDataSizePos, dataSize);
    
    FLVLog(@"Checkpoint #%i\n\n  enc = %p\n  *enc = %p\n\n  buffer = %p\n  *buffer = %p\n\n  metaDataSizePos = %p\n  *metaDataSizePos = %p\n\n  dataSize = %llu", kNumCheckpoint++, enc, (void*)*enc, buffer, (void*)*buffer, metaDataSizePos, (void*)*metaDataSizePos, dataSize);
    
    *buffer = (uint8_t*)enc;
    
    put_be32(buffer, dataSize + 11);                                    // Write the previous tag size                                  0xAA
    
#pragma mark - Audio Data Start
    put_byte(buffer, FLV_TAG_TYPE_AUDIO);                               // Audio information flag                                       0x08
    sizePos = (int64_t)*buffer;                                         // Save the location of size, TS, and stream ID
    put_be24(buffer, 0);                                                // Size
    put_be24(buffer, 0);                                                // Timestamp
    put_byte(buffer, 0);                                                // Timestamp extension
    put_be24(buffer, 0);                                                // Stream ID
                                                                        // Flags
    put_byte(buffer, FLV_CODECID_AAC | FLV_SAMPLERATE_44100HZ | FLV_SAMPLESIZE_16BIT | FLV_STEREO);
    put_byte(buffer, 0);                                                // AAC sequence header
    put_byte(buffer, 0x12);                                             // 0x12
    put_byte(buffer, 0x08);                                             // 0x08
    
    dataSize = (int)*buffer - (sizePos + 10);
    
    ref = *buffer;
    *buffer = (uint8_t*)sizePos;
    
    put_be24(buffer, dataSize);
    
    *buffer = ref;
    
    put_be32(buffer, dataSize + 11);
    
#pragma mark - Video Data Start
    FLVLog(@"Checkpoint #%i\n\n  *buffer = %p\n  **buffer = %p\n\n  dataSize = %i", kNumCheckpoint++, *buffer, (void*)**buffer, *buffer - pStart);
    
    put_byte(buffer, FLV_TAG_TYPE_VIDEO);                               // Video information flag                                       0x09
    sizePos = (int64_t)*buffer;                                         // Store the location of the size, TS, and stream ID
    put_be24(buffer, 0);                                                // Size                                                         0x0
    put_be24(buffer, 0);                                                // Timestamp                                                    0x0
    put_byte(buffer, 0);                                                // Timestamp extension                                          0x0
    put_be24(buffer, 0);                                                // Stream ID                                                    0x0
    
    put_byte(buffer, FLV_CODECID_H264 | FLV_FRAME_KEY);                 // Flags                                                        0x17
    put_byte(buffer, 0);                                                // AvcC Header                                                  0x0
    put_be24(buffer, 0);                                                // Sequence time                                                0x0
    
    avcCHeader header((const BYTE*)[avcC bytes], [avcC length]);        // Wrapper for avcC data
    
    SeqParamSet seqParams;                                              // Wrapper for SPS
    seqParams.Parse(header.sps());                                      // Parse the header's SPS data
    
    NALUnit *sps = header.sps();                                        // Pointer to SPS
    NALUnit *pps = header.pps();                                        // Pointer to PPS
    
    FLVLog(@"Checkpoint #%i: SPS/PPS\n\n  sps.Profile() = %i\n  sps.Compat() = %i\n  sps.Level() = %i", kNumCheckpoint++, seqParams.Profile(), seqParams.Compat(), seqParams.Level());
    
    put_byte(buffer, 1);                                                // Version                                                      0x1
    put_byte(buffer, seqParams.Profile());                              // Profile                                                      0x4D
    put_byte(buffer, seqParams.Compat());                               // Profile compatability                                        0x0
    put_byte(buffer, seqParams.Level());                                // Level                                                        0x1E
    put_byte(buffer, 0xff);                                             // 6 bits reserved (111111) + 2 bits nal size length - 1 (11)   0xFF
    put_byte(buffer, 0xe1);                                             // 3 bits reserved (111) + 5 bits number of sps (00001)         0xE1
    
    NSData *spsData = [NSData dataWithBytes:sps->Start() length:sps->Length()];
    NSData *ppsData = [NSData dataWithBytes:pps->Start() length:pps->Length()];
    
    FLVLog(@"Checkpoint #%i\n\n  spsDataLength = %i\tsps->Length() = %i\n  ppsDataLength = %i\t\tpps->Length() = %i", kNumCheckpoint++, [spsData length], sps->Length(), [ppsData length], pps->Length());
    
    put_be16(buffer, sps->Length());                                    // Size of SPS                                                  0xE
    put_buff(buffer, (uint8_t*)[spsData bytes], sps->Length());         // Copy from spsData to sps->Length()
    
    put_byte(buffer, 1);                                                // Number of PPS                                                0x1
    put_be16(buffer, pps->Length());                                    // Size of PPS                                                  0x5
    put_buff(buffer, (uint8_t*)[ppsData bytes], pps->Length());         // Copy from ppsData to pps->Length()
    
    dataSize = (int)*buffer - ((int)sizePos + 10);                  // Get the size from the value of buffer - avcCSizePos
    
    ref = *buffer;
    *buffer = (uint8_t*)sizePos;
    
    put_be24(buffer, dataSize);                                         // Write the size of the SPS/PPS data at avcCSizePos            0xED
    
    *buffer = ref;
    
    put_be32(buffer, dataSize + 11);                                    // Write previous tag size                                      0xE8
    
    dataSize = *buffer - pStart;                                        // Get the current size of the data
    
    FLVLog(@"Checkpoint #%i\n\n  dataSize = %llu  \tbuffer = %p\n  *buffer = %p\n  **buffer = %p", kNumCheckpoint++, dataSize, buffer, *buffer, (void*)**buffer);
    
    *buffer = pStart;                                                   // Reset the pointer back to pStart
    
    FLVLog(@"Checkpoint #%i: End of method\n  dataSize = %llu\n\n  pStart = %p\n\n  \tbuffer = %p\n  *buffer = %p\n  **buffer = %p\n\n", kNumCheckpoint++, dataSize, pStart, buffer, *buffer, (void*)**buffer);
    
    return dataSize;                                                    // Return the size of the data
}

- (int)writeAvcCHeader:(NSData*)avcC toBuffer:(uint8_t**)buffer {
    uint8_t **pBuffer = buffer;
    int dataSize;
    
    avcCHeader header((const BYTE*)[avcC bytes], [avcC length]);
    
    SeqParamSet seqParams;
    seqParams.Parse(header.sps());
    
    NALUnit *sps = header.sps();
    NALUnit *pps = header.pps();
    
    put_byte(pBuffer, 1);                                               // Version
    put_byte(pBuffer, seqParams.Profile());                             // Profile
    put_byte(pBuffer, seqParams.Compat());                              // Profile compatability
    put_byte(pBuffer, seqParams.Level());                               // Level
    put_byte(pBuffer, 0xff);                                            // 6 bits reserved (111111) + 2 bits nal size length - 1 (11)
    put_byte(pBuffer, 0xe1);                                            // 3 bits reserved (111) + 5 bits number of sps (00001)
    
    put_be16(pBuffer, sps->Length());                                   // Size of SPS
    put_buff(pBuffer, sps->Start(), sps->Length());                     // Copy from sps->Start() to sps->Length()
    
    put_byte(pBuffer, 1);                                               // Number of PPS
    put_be16(pBuffer, pps->Length());                                   // Size of PPS
    put_buff(pBuffer, pps->Start(), pps->Length());                     // Copy from pps->Start() to pps->Length()
    
    dataSize = pBuffer - buffer;
    
    return dataSize;
}

- (int)writeNALU:(uint8_t*)nalu ofSize:(int)naluSize toPacket:(uint8_t**)packet time:(double)pts keyframe:(BOOL)isKeyframe {
    uint8_t *pStart         = *packet;
    unsigned newTS          = pts;
    int32_t flagsSize       = 0;
    int flags               = 0;
    int dataSize            = 0;
    
    FLVLog(@"Checkpoint #%i: Start of method\n  \tNALUSize = %i\n  \tpacket = %p\n  \t*packet = %p\n  \t**packet = %p", kNumCheckpoint++, naluSize, packet, *packet, (void*)**packet);
    
    put_byte(packet, FLV_TAG_TYPE_VIDEO);                       // 0x09
    
    FLVLog(@"Checkpoint #%i\n  \tpacket = %p\n \t*packet = %p\n \t**packet = %p", kNumCheckpoint++, packet, *packet, (void*)**packet);
    
    flags               = FLV_CODECID_H264;                     // 0x07
    flagsSize           = 5;                                    // Reserve 5 bytes for H264 codec flags
    
    if (isKeyframe) {
        flags           |= FLV_FRAME_KEY;                       // Add keyframe flag
    }else {
        flags           |= FLV_FRAME_INTER;                     // Add inter frame flag
    }
    
    FLVLog(@"Checkpoint #%i\n  \tpacket = %p\n  \t*packet = %p\n  \t**packet = %p", kNumCheckpoint++, packet, *packet, (void*)**packet);
    
    put_be24(packet, naluSize + flagsSize);                    // Write the size of the data and flags
    put_be24(packet, newTS);                                   // Write the timestamp
    put_byte(packet, (newTS >> 24) & 0x7F);                    // Timestamps are signed, 32bits
    
    FLVLog(@"Checkpoint #%i\n  \tpacket = %p\n  \t*packet = %p\n  \t**packet = %p", kNumCheckpoint++, packet, *packet, (void*)**packet);
    
    put_be24(packet, 0);                                       // FLV Reserved                                     0x0 0x0 0x0
    put_byte(packet, flags);                                   // Write the flags                                  0x17 || 0x27
    put_byte(packet, 1);                                       // Picture Data                                     0x1
    put_be24(packet, 0);                                       // Write the b frame TS                             0x0 0x0 0x0
    put_buff(packet, nalu, naluSize);                          // Write the NALU to packet
    
    FLVLog(@"Checkpoint #%i\n  \tpacket = %p\n  \t*packet = %p\n  \t**packet = %p", kNumCheckpoint++, packet, *packet, (void*)**packet);
    
    put_be32(packet, naluSize + flagsSize + 11);               // Previous tag size
    
    dataSize = *packet - pStart;                               // Get the size of the data
    
    FLVLog(@"Checkpoint #%i: End of method\n  \tdataSize = %i\n\n  \tpacket = %p\n \t*packet = %p\n \t**packet = %p", kNumCheckpoint++, dataSize, packet, *packet, (void*)**packet);
    
    *packet = pStart;                                          // Reset the pointer position
    
    return dataSize;
}

- (int)writeAAC:(uint8_t *)aacData ofSize:(int)aacSize toPacket:(uint8_t **)packet time:(double)pts {
    uint8_t *pStart     = *packet;
    unsigned newTS      = pts;
    int32_t flagSize    = 0;
    int flags           = 0;
    int dataSize        = 0;
    
    flags = FLV_CODECID_AAC | FLV_SAMPLERATE_44100HZ | FLV_SAMPLESIZE_16BIT | FLV_STEREO;
    flagSize = 2;
    
    put_byte(packet, FLV_TAG_TYPE_AUDIO);                      // Write the audio flag                          0x08
    put_be24(packet, aacSize + flagSize);                      // Write the size of the data and flags
    put_be24(packet, newTS);                                   // Write the timestamp
    put_byte(packet, (newTS >> 24) & 0x7f);                    // Timestamps are signed, 32 bits
    put_be24(packet, 0);                                       // FLV Reserved                              0x00 0x00 0x00
    put_byte(packet, flags);                                   // Write flags
    put_byte(packet, 1);                                       // AAC Raw                                       0x01
    put_buff(packet, aacData, aacSize);                        // Write the AAC data to packet
    put_be32(packet, aacSize + flagSize + 11);
    
    dataSize = *packet - pStart;
    
    *packet = pStart;
    
    return dataSize;
}

- (int)writeStreamTrailer:(uint8_t**)buffer time:(unsigned)ts {
    int64_t fileSize    = 0;
    double duration     = 0;
    int dataSize        = 0;
    uint8_t *pStart     = *buffer;
    char pBuf[128];
    char* pEnd          = pBuf + sizeof(pBuf);
    char *enc;
    AVal av;
    
    put_byte(buffer, FLV_TAG_TYPE_VIDEO);
    put_be24(buffer, 5);                                                // Tag Data Size
    put_be24(buffer, ts);                                               // lower 24 bits of timestamp in ms
    put_byte(buffer, (ts >> 24) & 0x7F);                                // MSB of ts in ms
    put_be24(buffer, 0);                                                // StreamId = 0
    put_byte(buffer, 23);                                               // ub[4] FrameType = 1, ub[4] CodecId = 7
    put_byte(buffer, 2);                                                // AVC end of sequence
    put_be24(buffer, 0);                                                // Always 0 for AVC EOS.
    put_be32(buffer, 16);                                               // Size of FLV tag
    
    /*  19 bytes */
    
    FLVLog(@"\n  \t*buffer = %p\n  \tenc = %p", *buffer, enc);
    
    enc = (char*)*buffer;
    
    FLVLog(@"\n  \t*buffer = %p\n  \tenc = %p", *buffer, enc);
    
    if (duration != 0) {
        STR2AVAL(av, (char*)"duration");
        enc = AMF_EncodeNamedNumber(enc, pEnd, &av, duration);
    }else {
        FLVLog(@"\nFailed to update header with correct duration");
    }
    
    if (fileSize != 0) {
        STR2AVAL(av, (char*)"filesize");
        enc = AMF_EncodeNamedNumber(enc, pEnd, &av, fileSize);
    }else {
        FLVLog(@"\nFailed to update header with correct filesize\n");
    }
    
    if (enc != (char*)*buffer)
        dataSize = enc - (char*)*buffer - 19;
    else
        dataSize = *buffer - pStart;
    
    FLVLog(@"dataSize = %i", dataSize);
    
    *buffer = pStart;
    
    return dataSize;
}

@end
