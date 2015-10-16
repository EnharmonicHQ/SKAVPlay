//
//  ENHExtendedSKVideoNode.h
//  SKAVPlay
//
//  Created by Jonathan Saggau on 6/19/14.
//  Copyright (c) 2014 Enharmonic. All rights reserved.
//

@import SpriteKit;

//TODO:
//Make everything smooth. I think I have some KVO getting in the way when updating sliders, for example.

extern NSString * const ENHExtendedSKVideoNodeErrorDomain;

typedef NS_ENUM(NSInteger, ENHExtendedSKVideoNodeError)
{
	ENHExtendedSKVideoNodeErrorAssetCannotBePlayed = 1
};

@interface ENHExtendedSKVideoNode : SKVideoNode

@property(nonatomic, weak, readonly)AVPlayer *avPlayer;
@property(nonatomic, strong)NSURL *videoContentURL;

//Includes compensation for preferredTransform
//valid only if readyToPlay is YES
@property(nonatomic, readonly)CGSize videoNaturalSize;
@property(nonatomic, readonly)CGSize videoNaturalSizeForScene;

@property(nonatomic, assign)BOOL autoLoopEnabled;
@property(nonatomic, assign)Float64 autoLoopStartNormalizedPlaybackPosition;
@property(nonatomic, assign)Float64 autoLoopEndNormalizedPlaybackPosition;

//ALL KVO-able
@property(nonatomic, assign)Float64 normalizedPlaybackPosition; // 0.0 ... 1.0
@property(nonatomic, assign)Float64 playbackPosition; //Seconds
@property(nonatomic, assign)float playbackRate; // 1.0 is "normal speed"

@property(nonatomic, readonly)BOOL readyToPlay;
@property(nonatomic, readonly)Float64 duration; //Seconds
@property(nonatomic, readonly)BOOL playing;
@property(nonatomic, assign)BOOL seekInProgress;

/**
 *  Initializes an `ENHExtendedSKVideoNode` object with the file path of a video located inside the application bundle.
 *
 *  This method does not call through to the super implementation. Instead this method calls through to the -[ENHExtendedSKVideoNode initWithAVPlayer:] designated initializer.
 *
 *  @param videoFile The video file path for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @see -videoNodeWithVideoFileNamed:
 *  @see -initWithAVPlayer:
 */
-(instancetype)initWithVideoFileNamed:(NSString *)videoFile;

/**
 *  Convenience initializer for an `ENHExtendedSKVideoNode` object with the file path of a video located inside the application bundle.
 *
 *  This method does not call through to the super implementation.
 *
 *  @param videoFile The video file path for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @see -initWithVideoFileNamed:
 *  @see -initWithAVPlayer:
 */
- (instancetype)initWithFileNamed:(NSString *)videoFile;

/**
 *  Initializes an `ENHExtendedSKVideoNode` object with the url of a video resource.
 *
 *  This method does not call through to the super implementation. Instead this method calls through to the -[ENHExtendedSKVideoNode initWithAVPlayer:] designated initializer.
 *
 *  @param url The video file url for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @discussion This mthod is called by the super implementation of -videoNodeWithVideoURL:
 *  @see -videoNodeWithVideoURL:
 *  @see -initWithAVPlayer:
 */
-(instancetype)initWithURL:(NSURL *)url;

/**
 *  Convenience initializer for an `ENHExtendedSKVideoNode` object with the url of a video resource.
 *
 *  This method does not call through to the super implementation.
 *
 *  @param url The video file url for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @discussion This mthod is called by the super implementation of -videoNodeWithVideoURL:
 *  @see -initWithVideoURL:
 *  @see -initWithAVPlayer:
 */
+(instancetype)videoNodeWithVideoURL:(NSURL *)videoURL;

/**
 *  Initializes an `ENHExtendedSKVideoNode` object with an `AVPlayer` instance.
 *
 *  This is the designated initializer.
 *
 *  @param player The player object for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @discussion This mthod is called by the super implementation of -videoNodeWithAVPlayer:
 *  @see -videoNodeWithAVPlayer:
 */
-(instancetype)initWithAVPlayer:(AVPlayer *)player NS_DESIGNATED_INITIALIZER;

/**
 *  Convenience initializer for an `ENHExtendedSKVideoNode` object with an `AVPlayer` instance.
 *
 *  This method does not call through to the super implementation. Instead this method calls through to the -[ENHExtendedSKVideoNode initWithVideoURL:] designated initializer.
 *
 *  @param player The player object for the video node.
 *
 *  @return The newly initialized video node.
 *
 *  @see -initWithAVPlayer:
 */
+(instancetype)videoNodeWithAVPlayer:(AVPlayer *)player;

@end
