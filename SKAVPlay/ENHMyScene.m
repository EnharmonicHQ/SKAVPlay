//
//  ENHMyScene.m
//  SKAVPlay
//
//  Created by Jonathan Saggau on 6/18/14.
//  Copyright (c) 2014 Jonathan Saggau. All rights reserved.
//

#import "ENHMyScene.h"
#import "ENHExtendedSKVideoNode.h"

@import AVFoundation;

@interface ENHMyScene ()

@end

@implementation ENHMyScene

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        self.backgroundColor = [SKColor colorWithRed:0.15 green:0.15 blue:0.3 alpha:1.0];
        [self setAnchorPoint:(CGPoint){0.5, 0.5}];
        [self setScaleMode:SKSceneScaleModeResizeFill];
    }
    return self;
}

-(void)didChangeSize:(CGSize)oldSize
{
    CGSize size = [self size];
    [self.videoNode setSize:size];
}

-(void)didMoveToView:(SKView *)view
{
    [view setIgnoresSiblingOrder:YES];
    if (self.videoNode == nil)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"movie2"
                                                         ofType:@"mov"];
        NSURL *assetURL = [NSURL fileURLWithPath:path];
        AVAsset *asset = [AVAsset assetWithURL:assetURL];
        AVPlayerItem *item = [[AVPlayerItem alloc] initWithAsset:asset];
        AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:item];
        ENHExtendedSKVideoNode *videoNode = [[ENHExtendedSKVideoNode alloc] initWithAVPlayer:player];
        [videoNode setSize:self.size];
        [self addChild:videoNode];
        [self setVideoNode:videoNode];
    }
}

@end
