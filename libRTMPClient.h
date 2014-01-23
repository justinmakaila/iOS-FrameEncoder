//
//  libRTMPClient.h
//  PresentRTMPStreamModule
//
//  Created by Justin Makaila on 7/20/13.
//  Copyright (c) 2013 Present, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <librtmp/rtmp.h>
#import <librtmp/log.h>
#import <librtmp/amf.h>

#import <openssl/crypto.h>

@protocol libRTMPClientDelegate <NSObject>
@optional
-(void)clientDidConnect;
-(void)clientDidConnectToStream;
-(void)clientDidDisconnect;
-(void)clientDidWriteData;
-(void)clientDidFailWithError:(NSError*)error;
@end

@interface libRTMPClient : NSObject

@property (unsafe_unretained) id<libRTMPClientDelegate> delegate;

-(id)init;
-(id)initWithDelegate:(id)delegate;

-(void)connect;
-(void)disconnect;

-(BOOL)isReadyForData;

-(BOOL)isConnected;
-(BOOL)isStreaming;

-(void)writeNALUToStream:(NSArray*)data time:(double)pts;
-(void)writeAACDataToStream:(NSData*)data time:(double)pts;

-(void)writeAvcCHeaderToStream:(NSData*)data;

@end