//
//  libRTMPClient.m
//  PresentRTMPStreamModule
//
//  Created by Justin Makaila on 7/20/13.
//  Copyright (c) 2013 Present, Inc. All rights reserved.
//

#import "libRTMPClient.h"
#import "FLVPacket.h"

#warning !FIX! Put your RTMP output URL here
#define outputURL ""

typedef enum {
    kConnectHost = 0,
    kConnectStream
}SOURCE;

@interface libRTMPClient () {
    RTMP *rtmp;             // RTMP Object
    
    FLVContext *flv;        // FLV context to manage contextual information (Offsets, start time, TS, last TS, etc)
    FLVPacket *flvPkt;      // Class to handle packetizing information
    
    BOOL connected;         // Is there a connection to the server?
    BOOL streaming;         // Is there a stream?
    
    int framesRecieved;     // The number of frames recieved
    int framesWritten;      // The number of frames written to stream
    
    int bytesRecieved;      // The number of bytes recieved
    int bytesWritten;       // The number of bytes written to stream
    
    NSData *avcC;           // Data reference to avcC information
    int avcCSize;           // Size of the avcC
    
    NSData *magicCookie;
    int magicCookieSize;
}

@end

// skip x bytes
void skip_bytes(uint8_t **data, uint8_t val) {
    *data += val;
}

// puts 8 bits
void put_byte(uint8_t **data, uint8_t val) {
    NSLog(@"***************** START of put_byte *****************");
    
    NSLog(@"Value = %i", val);
    
    assert(val >= -128 && val <= 255);
    *data[0]++ = val;
    
    NSLog(@"Value of data\n \t*data[0] = %p", (void*)*data[0]);
    NSLog(@"Value of data pointers\n \tdata = %p\n \t*data = %p\n \t*data[0] = %p", data, *data, (void*)*data[0]);
    NSLog(@"***************** END of put_byte *****************");
}

// puts 16 bits
void put_be16(uint8_t **data, unsigned int val) {
    NSLog(@"***************** START of put_be16 *****************");
    
    put_byte(data, (int)val >> 8);
    put_byte(data, (uint8_t)val);
    
    NSLog(@"***************** END of put_be16 *****************");
}

// puts 32 bits
void put_be32(uint8_t **data, unsigned int val) {
    NSLog(@"***************** START of put_be32 *****************");
    
    NSLog(@"Value = %i", val);
    put_byte(data,           val >> 24);
    put_byte(data, (uint8_t)(val >> 16));
    put_byte(data, (uint8_t)(val >> 8));
    put_byte(data, (uint8_t) val);
    
    NSLog(@"***************** END of put_be32 *****************");
}

// puts 24 bits
void put_be24(uint8_t **data, unsigned int val) {
    NSLog(@"***************** START of put_be24 *****************");
    
    NSLog(@"Value = %i", val);
    put_be16(data, (int)val >> 8);
    put_byte(data, (uint8_t)val);
    
    NSLog(@"***************** END of put_be24 *****************");
}

// puts buffer
void put_buff(uint8_t **data, const uint8_t *src, int32_t srcsize) {
    NSLog(@"***************** START of put_buff *****************");
    
    memcpy(*data, src, srcsize);
    *data += srcsize;
    
    NSLog(@"***************** END of put_buff *****************");
}

// puts 8 bit representation of each char
void put_tag(uint8_t **data, const char *tag) {
    NSLog(@"***************** START of put_tag *****************");
    
    while (*tag) {
        DLLog(@"\n\n \t *tag = %c", *tag);
        put_byte(data, *tag++);
    }
    
    NSLog(@"***************** END of put_tag *****************");
}

@implementation libRTMPClient

-(id)init {
    self = [super init];
    if (self) {
        flvPkt = [[FLVPacket alloc]init];
        
        connected = NO;
        streaming = NO;
    }
    
    return self;
}

-(id)initWithDelegate:(id)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        flvPkt = [[FLVPacket alloc]init];
        
        connected = NO;
        streaming = NO;
    }
    
    return self;
}

#pragma mark - Connection Lifecycle

-(void)connect {
    rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    RTMP_SetupURL(rtmp, outputURL);
    RTMP_EnableWrite(rtmp);
    RTMP_LogSetLevel(RTMP_LOGERROR);
    
    if(!RTMP_Connect(rtmp, NULL)) {
        [self fail:kConnectHost];
        return;
    }else
        connected = YES;
    
    [_delegate clientDidConnect];
    
    if (!RTMP_ConnectStream(rtmp, 0)) {
        [self fail:kConnectStream];
        return;
    }else
        streaming = YES;
    
    [_delegate clientDidConnectToStream];
}

-(void)disconnect {
    if (connected) {
        if ([self writeStreamTrailer] != 0) {
            RTMP_Close(rtmp);
            RTMP_Free(rtmp);
            
            connected = NO;
            [_delegate clientDidDisconnect];
        }
    }
}

-(void)fail:(int)source {
    RTMP_Close(rtmp);
    RTMP_Free(rtmp);
    
    connected = NO;
    streaming = NO;
    
    NSString *localizedDesc;
    switch (source) {
        case 0:
            localizedDesc = @"Client failed to connect to host!";
            break;
        case 1:
            localizedDesc = @"Client failed to connect to stream!";
        default:
            break;
    }
    
    NSError *error = [NSError errorWithDomain:@"libRTMPClient"
                                         code:100
                                     userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                               @"localizedDescription", localizedDesc, nil]];
    [_delegate clientDidFailWithError:error];
}

-(BOOL)isReadyForData {
    return (connected && streaming);
}

-(BOOL)isConnected {
    return connected;
}

-(BOOL)isStreaming {
    return streaming;
}

#pragma mark - I/O

-(void)writeAvcCHeaderToStream:(NSData*)data {
    avcC            = data;
    avcCSize        = [data length];
    int ret         = 0;
    char cBuffer[4096];
    uint8_t *buffer = (uint8_t*)cBuffer;
    
    NSLog(@"Checkpoint #%i: Will call writeStreamHeader:ofSize:withAvcC:ofSize:\n  cBuffer = %p\n  sizeof(cBuffer) = %ld\n\n  buffer = %p\n  *buffer = %p\n  sizeof(buffer) = %ld", kNumCheckpoint++, cBuffer, sizeof(cBuffer), buffer, (void*)*buffer, sizeof(*buffer));
    
    ret = [flvPkt writeStreamHeader:&buffer ofSize:sizeof(cBuffer) withAvcC:avcC ofSize:avcCSize];
    
    NSLog(@"Checkpoint #%i: Did call writeStreamHeader:ofSize:withAvcC:ofSize:\n returned %i\n  buffer = %p\n  *buffer = %p\n  cBuffer = %p", kNumCheckpoint++, ret, buffer, (void*)*buffer, cBuffer);
    
    RTMP_Write(rtmp, (const char*)buffer, ret);
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *  NALUs are delivered to the server frame by frame.  *
 *  Each packet must contain a full frame.             *
 *  Format is as follows:                              *
 *   [4 byte length][4...n][4 byte length][n+4...n]      *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * */
-(void)writeNALUToStream:(NSArray*)data time:(double)pts {
    int ret                 = 0;                                // Returned size of NALU
    int size                = 0;                                // Size of NALU
    char cFrame[MAX_H264_FRAMESIZE];                            // Allocate a buffer of MAX_H264_FRAMESIZE to hold the frame
    char cBuffer[MAX_H264_FRAMESIZE];                           // Allocate a buffer of MAX_H264_FRAMESIZE to hold the packet
    uint8_t* frame          = (uint8_t*)cFrame;                 // Buffer to hold NALU data
    uint8_t* pFrameStart    = (uint8_t*)frame;                  // Pointer to the start of the frame
    uint8_t* buffer         = (uint8_t*)cBuffer;                // Buffer to hold encoded packet
    
    uint8_t* fNALU          = (uint8_t*)[data[0] bytes];        // Get the first NALU
    int fSize               = [data[0] length];                 // Get the size of the first NALU
    int naltype             = fNALU[0] & 0x1f;                  // Get the type of the NALU(s)
    
    put_be32(&frame, fSize);                                    // Write the size of the first NALU to frame
    put_buff(&frame, fNALU, fSize);                             // Write the first NALU to frame
    
    if ([data count] > 1) {
        uint8_t* sNALU      = (uint8_t*)[data[1] bytes];        // Get the second NALU
        int sSize           = [data[1] length];                 // Get the size of the second NALU
        
        put_be32(&frame, sSize);                                // Write the size of the second NALU to frame
        put_buff(&frame, sNALU, sSize);                         // Write the second NALU to frame
    }
    
    size                    = frame - pFrameStart;              // Get the size of the data written to frame
    frame                   = pFrameStart;                      // Reset the frame pointer to the beginning
    
    NSLog(@"Checkpoint #%i: Will call writeNALU:ofSize:toPacket:time:keyframe:\n\n  \tsize = %i", kNumCheckpoint++, size);
    
    ret = [flvPkt writeNALU:frame                               // Write frame
                     ofSize:size                                // of size
                   toPacket:&buffer                             // to buffer
                       time:pts                                 // With TS pts
                   keyframe:(naltype == 5)];                    // If naltype == 5, frame is keyframe
    
    if (ret < 0) {
        // TODO: Implement error handling for failed writes to packet
        return;
    }
    
    NSLog(@"\n  \tReturned dataSize = %i", ret);
    
    RTMP_Write(rtmp, (const char*)buffer, ret);           // Write the buffer to RTMP
}

-(void)writeAACDataToStream:(NSData*)data time:(double)pts {
    int ret = 0;
    char cAudioFrame[MAX_H264_FRAMESIZE];
    uint8_t* audioFrame = (uint8_t*)cAudioFrame;
    
    uint8_t* audioData = (uint8_t*)[data bytes];
    int audioSize = [data length];
    
    if (audioSize == 0) return;
    
    ret = [flvPkt writeAAC:audioData
                    ofSize:audioSize
                  toPacket:&audioFrame
                      time:pts];
    
    if (ret < 0) {
        // TODO: Implement error handling for failed writes to packet
        return;
    }
    
    NSLog(@"Write aac returned %i", ret);
    
    ret = RTMP_Write(rtmp, (const char*)audioFrame, ret);
    
    NSLog(@"\n  \tRTMP_Write returned %i", ret);
}

-(int)writeStreamTrailer {
    int ret = 0;
    char cBuf[256];
    uint8_t* buffer = (uint8_t*)cBuf;
    ret = [flvPkt writeStreamTrailer:&buffer time:0];
    
    ret = RTMP_Write(rtmp, (const char*)buffer, ret);
    
    NSLog(@"\n  \tRTMP_Write returned %i", ret);
    
    return ret;
}

@end
