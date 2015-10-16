//
//  ENHExtendedSKVideoNode.m
//  SKAVPlay
//
//  Created by Jonathan Saggau on 6/19/14.
//  Copyright (c) 2014 Enharmonic. All rights reserved.
//

#import "ENHExtendedSKVideoNode.h"
@import AVFoundation;

static void *ENHExtendedSKVideoNodePlayerItemObservationContext = &ENHExtendedSKVideoNodePlayerItemObservationContext;
static void *ENHExtendedSKVideoNodeStatusObservationContext = &ENHExtendedSKVideoNodeStatusObservationContext;

NSString * const ENHExtendedSKVideoNodeErrorDomain = @"ENHExtendedSKVideoNodeErrorDomain";

@interface ENHExtendedSKVideoNode (KeyValueObservingCustomization)

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key;

@end

@interface ENHExtendedSKVideoNode ()

@property(nonatomic, weak, readwrite)AVPlayer *avPlayer;
@property(nonatomic, strong)AVURLAsset *asset;
@property(nonatomic, assign)id timeObservationToken;
@property(nonatomic, assign)BOOL seekToZeroBeforePlay;

@end

@implementation ENHExtendedSKVideoNode
{
    __weak AVPlayerItem *_cachedCurrentItem;
    Float64 _cachedCurrentItemDuration;
}

-(instancetype)initWithAVPlayer:(AVPlayer *)player
{
    self = [super initWithAVPlayer:player];
    if (self != nil)
    {
        _avPlayer = player;
        [_avPlayer setActionAtItemEnd:AVPlayerActionAtItemEndNone];
        _autoLoopEnabled = NO;
        _autoLoopEndNormalizedPlaybackPosition = 1.0;
        _autoLoopStartNormalizedPlaybackPosition = 0.0;
        
        [self observePlayerItem];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    NSAssert2(NO, @"%@ does not work with %@. Please use -initWithAVPlayer:", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    self = [self initWithAVPlayer:nil];
    return self;
}

+(instancetype)videoNodeWithAVPlayer:(AVPlayer *)player
{
    return [[[self class] alloc] initWithAVPlayer:player];
}

-(instancetype)initWithURL:(NSURL *)url
{
    AVPlayer *player = [[AVPlayer alloc] init];
    self = [self initWithAVPlayer:player];
    if (self)
    {
        [self setVideoContentURL:url];
    }
    return self;
}

-(instancetype)initWithVideoURL:(NSURL *)url
{
    return [self initWithURL:url];
}

+(instancetype)videoNodeWithVideoURL:(NSURL *)videoURL
{
    return [[[self class] alloc] initWithURL:videoURL];
}

-(instancetype)initWithVideoFileNamed:(NSString *)videoFile
{
    return [self initWithFileNamed:videoFile];
}

- (instancetype)initWithFileNamed:(NSString *)videoFile
{
    NSString *pathExtension = [videoFile pathExtension];
    NSString *filename = [[videoFile lastPathComponent] stringByDeletingPathExtension];
    NSString *subdirectory = [videoFile stringByDeletingLastPathComponent];
    NSURL *videoURL = [[NSBundle mainBundle] URLForResource:filename withExtension:pathExtension subdirectory:subdirectory];
    
    return [self initWithURL:videoURL];
}

+(instancetype)videoNodeWithVideoFileNamed:(NSString *)videoFile
{
    return [[[self class] alloc] initWithFileNamed:videoFile];
}

-(void)dealloc
{
    [self unobservePlayerItem];
    [self removePlayerTimeObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Observation

-(void)observePlayerItem
{
    NSString *playerItemKeypath = [NSString stringWithFormat:@"%@.%@",
                         NSStringFromSelector(@selector(avPlayer)),
                         NSStringFromSelector(@selector(currentItem))];
    [self addObserver:self
           forKeyPath:playerItemKeypath
              options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
              context:ENHExtendedSKVideoNodePlayerItemObservationContext];
    
    NSString *playerItemStatusKeypath = [NSString stringWithFormat:@"%@.%@",
                         playerItemKeypath,
                         NSStringFromSelector(@selector(status))];
    [self addObserver:self
           forKeyPath:playerItemStatusKeypath
              options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
              context:ENHExtendedSKVideoNodeStatusObservationContext];
}

-(void)unobservePlayerItem
{
    NSString *playerItemKeypath = [NSString stringWithFormat:@"%@.%@",
                                   NSStringFromSelector(@selector(avPlayer)),
                                   NSStringFromSelector(@selector(currentItem))];
    [self removeObserver:self
              forKeyPath:playerItemKeypath
                 context:ENHExtendedSKVideoNodePlayerItemObservationContext];
    
    NSString *playerItemStatusKeypath = [NSString stringWithFormat:@"%@.%@",
                                         playerItemKeypath,
                                         NSStringFromSelector(@selector(status))];
    [self removeObserver:self
              forKeyPath:playerItemStatusKeypath
                 context:ENHExtendedSKVideoNodeStatusObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == ENHExtendedSKVideoNodeStatusObservationContext)
    {
        [self playerItemStatusDidChange:change object:object];
    }
    else if (context == ENHExtendedSKVideoNodePlayerItemObservationContext)
    {
        [self playerItemDidChange:change object:object];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)playerItemDidChange:(NSDictionary *)change object:(id)object
{
    NSAssert([[NSThread currentThread] isMainThread], @"not on the main thread");
    
    AVPlayerItem *previousItem = change[NSKeyValueChangeOldKey];
    if (previousItem)
    {
        /* Stop observing our prior AVPlayerItem, if we have one. */
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:previousItem];
    }
    
    AVPlayerItem *currentPlayerItem = [self.avPlayer currentItem];
    if (currentPlayerItem)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:currentPlayerItem];
    }
}

-(void)playerItemStatusDidChange:(NSDictionary *)change object:(id)object
{
    AVPlayerItemStatus status = [self.avPlayer.currentItem status];
    switch (status)
    {
            /* Indicates that the status of the player is not yet known because
             it has not tried to load new media resources for playback */
        case AVPlayerItemStatusUnknown:
        {
            [self removePlayerTimeObserver];
        }
            break;
            
        case AVPlayerItemStatusReadyToPlay:
        {
			NSAssert(isfinite([self duration]), @"Duration is *NOT* available upon ready to play.");
			NSAssert([self duration] > 0.0, @"Duration should be greater than zero upon ready to play.");
			
            /* Once the AVPlayerItem becomes ready to play, i.e.
             [playerItem status] == AVPlayerItemStatusReadyToPlay,
             its duration can be fetched from the item. */
            [self addPlayerTimeObserver];
        }
            break;
            
        case AVPlayerItemStatusFailed:
        {
            AVPlayerItem *playerItem = (AVPlayerItem *)object;
            NSError *error = [playerItem error];
            [self assetFailedToPrepareForPlayback:error];
        }
            break;
    }
}

-(void)addPlayerTimeObserver
{
    CMTime playerDuration = [self.avPlayer.currentItem duration];
    if (CMTIME_IS_INVALID(playerDuration) || self.timeObservationToken != nil)
    {
        return;
    }
    
    Float64 duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        __weak typeof(self) weakSelf = self;
        self.timeObservationToken = [self.avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 60)
                                                                                queue:NULL /* If you pass NULL, the main queue is used. */
                                                                           usingBlock:^(CMTime time) {
                                                                               [weakSelf willChangeValueForKey:@"normalizedPlaybackPosition"];
                                                                               [weakSelf willChangeValueForKey:@"playbackPosition"];
                                                                               [weakSelf willChangeValueForKey:@"playbackRate"];

                                                                               [weakSelf loopBackIfNeededOnMainThread];

                                                                               [weakSelf didChangeValueForKey:@"normalizedPlaybackPosition"];
                                                                               [weakSelf didChangeValueForKey:@"playbackPosition"];
                                                                               [weakSelf didChangeValueForKey:@"playbackRate"];
                                                                           }];
    }
}

-(void)removePlayerTimeObserver
{
    if ([self timeObservationToken] != nil)
    {
        [self.avPlayer removeTimeObserver:self.timeObservationToken];
        self.timeObservationToken = nil;
    }
}

#pragma mark - Playback

-(void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    NSParameterAssert(asset);
    NSAssert(asset == [self asset], @"local asset variable doesn't match property. Did asset change?");
    [self removePlayerTimeObserver];
    
    /* Make sure that the value of each key has loaded successfully. */
    for (NSString *thisKey in requestedKeys)
    {
        NSError *error = nil;
        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        if (keyStatus == AVKeyValueStatusFailed)
        {
            [self assetFailedToPrepareForPlayback:error];
            
            /* EARLY RETURN */
            return;
        }
    }
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
    {
        /* Generate an error describing the failure. */
        NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
        NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
        NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : localizedDescription,
                                     NSLocalizedFailureReasonErrorKey : localizedFailureReason };
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:ENHExtendedSKVideoNodeErrorDomain
                                                                code:ENHExtendedSKVideoNodeErrorAssetCannotBePlayed
                                                            userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        /* EARLY RETURN */
        return;
    }
    
    /* At this point we're ready to set up for playback of the asset. */
    AVPlayerItem *playerItem = nil;
    AVAssetTrack *assetTrack =  [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    
    CGAffineTransform preferredTransform = assetTrack.preferredTransform;
    if (CGAffineTransformEqualToTransform(asset.preferredTransform, preferredTransform))
    {
        playerItem = [AVPlayerItem playerItemWithAsset:asset];
    }
    else
    {
        // create a layer instruction to set the preferred transform
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:assetTrack];
        
        [layerInstruction setTransform:assetTrack.preferredTransform atTime:kCMTimeZero];
        
        // add the layer instruction to an instruction object
        AVMutableVideoCompositionInstruction *videoCompositionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
        videoCompositionInstruction.layerInstructions = @[layerInstruction];
        
        // create a video composition with the instructions
        AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.instructions = @[videoCompositionInstruction];
        videoComposition.frameDuration = CMTimeMake(1, 30);
        videoComposition.renderSize = assetTrack.naturalSize;
        
        /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
        playerItem = [AVPlayerItem playerItemWithAsset:asset];
        [playerItem setVideoComposition:videoComposition];
        
    }

    [self setSeekToZeroBeforePlay:NO];
    
    NSParameterAssert(self.avPlayer);
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if ([self.avPlayer currentItem] != playerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [self.avPlayer replaceCurrentItemWithPlayerItem:playerItem];
    }
}

-(void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler
{
    if (CMTIME_IS_VALID(time) && [self.avPlayer status] == AVPlayerStatusReadyToPlay)
    {
        [self setSeekToZeroBeforePlay:NO];
        
        CMTime tolerance = kCMTimeZero;
        
        [self removePlayerTimeObserver];
        AVPlayerItem *item = [self.avPlayer currentItem];
        
        float preSeekRate = [self.avPlayer rate];
        [self setSeekInProgress:YES];
        [self.avPlayer setRate:0.0f];
        
        __weak typeof(self) weakSelf = self;
        [item seekToTime:time toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:^(BOOL finished) {
            if (finished)
            {
                [weakSelf addPlayerTimeObserver];
                [weakSelf setSeekInProgress:NO];
                [weakSelf.avPlayer setRate:preSeekRate];
            }
            if (completionHandler)
            {
                completionHandler(finished);
            }
        }];
    }
}

#pragma mark - Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 **
 **  1) values of asset keys did not load successfully,
 **  2) the asset keys did load successfully, but the asset is not
 **     playable
 **  3) the item did not become ready to play.
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self setPlaybackRate:0.0f];
    [self setAsset:nil];
    
    NSLog(@"-[%@ %@], error: %@", [self class], NSStringFromSelector(_cmd), error);
    
    // TODO: Bubble the error up to the UI.
}

#pragma mark - Notification Handling

-(void)loopBackIfNeededOnMainThread
{
    if ([[NSThread currentThread] isMainThread])
    {
        Float64 playbackPosition = [self normalizedPlaybackPosition];
        Float64 loopbackPlaybackPosition = [self autoLoopEndNormalizedPlaybackPosition];
        if ([self autoLoopEnabled] && playbackPosition >= loopbackPlaybackPosition)
        {
            float previousPlaybackRate = [self playbackRate];
            Float64 normalizedStartTime = [self autoLoopStartNormalizedPlaybackPosition];
            Float64 duration = [self duration];
            Float64 startTimeInSeconds = normalizedStartTime * duration;
            CMTime startTime = CMTimeMakeWithSeconds(startTimeInSeconds, 60);
            [self seekToTime:startTime completionHandler:^(BOOL finished) {
                if (finished)
                {
                    [self setPlaybackRate:previousPlaybackRate];
                }
            }];
        }
        else if (playbackPosition >= 1.0)
        {
            [self setPlaybackRate:0.0f];
            
            /* After the movie has played to its end time, seek back to time zero
             to play it again. */
            [self setSeekToZeroBeforePlay:YES];
        }
    }
    else
    {
        __weak typeof(self) weakSelf = self;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf loopBackIfNeededOnMainThread];
        });
    }
}

/* Called when the player item has played to its end time. */
-(void)playerItemDidReachEnd:(NSNotification *)notification
{
    [self loopBackIfNeededOnMainThread];
}

#pragma mark - Accessors

-(CGSize)videoNaturalSizeForScene
{
    CGSize videoSize = CGSizeZero;
    if (self.parent != nil && self.scene != nil)
    {
        videoSize = [self videoNaturalSize];
        CGRect targetRect = AVMakeRectWithAspectRatioInsideRect(videoSize, self.scene.frame);
        videoSize = targetRect.size;
    }
    return videoSize;
}

-(CGSize)videoNaturalSize
{
    CGSize videoSize = CGSizeZero;
    if (self.avPlayer.currentItem != nil && self.readyToPlay)
    {
        AVAsset *videoAsset = [self.avPlayer.currentItem asset];
        NSArray *tracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
        if ([tracks count] > 0)
        {
            AVAssetTrack *track = [tracks firstObject];

            CGRect trackRect = CGRectMake(0, 0, track.naturalSize.width, track.naturalSize.height);
            trackRect = CGRectApplyAffineTransform(trackRect, track.preferredTransform);
            videoSize = trackRect.size;
        }
    }
    return videoSize;
}

-(void)setVideoContentURL:(NSURL *)videoContentURL
{
    if (_videoContentURL != videoContentURL)
    {
        _videoContentURL = videoContentURL;
        
        if (_videoContentURL)
        {
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:_videoContentURL options:nil];
            [self setAsset:asset];
            __weak AVURLAsset *weakAsset = asset;
            
            NSArray *keys = @[@"playable", @"duration"];
            
            __weak typeof(self) weakSelf = self;
            [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf prepareToPlayAsset:weakAsset withKeys:keys];
                });
            }];
        }
    }
}

-(BOOL)readyToPlay
{
    AVPlayerStatus status = [self.avPlayer status];
    return status == AVPlayerStatusReadyToPlay;
}

//0 ... 1
-(void)setPlaybackRate:(float)rate
{
    if (rate <= 0.0)
    {
        [self.avPlayer setRate:rate];
        [self pause];
    }
    else
    {
        [self play];
        
        if ([self seekToZeroBeforePlay])
        {
            __weak typeof(self) weakSelf = self;
            [self seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                [weakSelf setSeekToZeroBeforePlay:NO];
                [weakSelf.avPlayer setRate:rate];
            }];
        }
        else
        {
            [self.avPlayer setRate:rate];
        }
    }
}

-(float)playbackRate
{
    return [self.avPlayer rate];
}

//0 ... 1
-(void)setNormalizedPlaybackPosition:(Float64)position
{
    AVPlayerItem *item = [self.avPlayer currentItem];
    CMTime currentCMTimeDuration = [item duration];
    CMTime newCMTime = CMTimeMultiplyByFloat64(currentCMTimeDuration, position);
    [self seekToTime:newCMTime completionHandler:nil];
}

//0 ... 1
-(Float64)normalizedPlaybackPosition
{
    CMTime currentCMTime = [self.avPlayer currentTime];
    Float64 currentTime = CMTimeGetSeconds(currentCMTime);
    Float64 duration = [self duration];
    Float64 normalizedPosition = currentTime / duration;
    return normalizedPosition;
}

-(void)setPlaybackPosition:(Float64)playbackPosition
{
    CMTime durationCMTime = [self.avPlayer.currentItem duration];
    Float64 duration = CMTimeGetSeconds(durationCMTime);
    Float64 position = playbackPosition * duration;
    CMTime newCMTime = CMTimeMultiplyByFloat64(durationCMTime, position);
    [self seekToTime:newCMTime completionHandler:nil];
}

-(Float64)playbackPosition
{
    CMTime currentCMTime = [self.avPlayer currentTime];
    Float64 currentTime = CMTimeGetSeconds(currentCMTime);
    return currentTime;
}

-(Float64)duration
{
    AVPlayerItem *item = [self.avPlayer currentItem];
    if (item != _cachedCurrentItem)
    {
        _cachedCurrentItem = item;
        CMTime currentCMTimeDuration = [item duration];
        _cachedCurrentItemDuration = CMTimeGetSeconds(currentCMTimeDuration);
    }
    return _cachedCurrentItemDuration;
}

-(BOOL)playing
{
    return [self playbackRate] > 0.0;
}

@end

@implementation ENHExtendedSKVideoNode (KeyValueObserving)

+(NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    if ([key isEqualToString:@"duration"])
    {
        keyPaths = [keyPaths setByAddingObject:@"avPlayer.currentItem.duration"];
    }
    
    if ([key isEqualToString:@"playbackPosition"] || [key isEqualToString:@"normalizedPlaybackPosition"])
    {
        keyPaths = [keyPaths setByAddingObject:@"avPlayer.currentTime"];
    }
    
    if ([key isEqualToString:@"playbackRate"] || [key isEqualToString:@"playing"])
    {
        keyPaths = [keyPaths setByAddingObject:@"avPlayer.rate"];
    }
    
    if ([key isEqualToString:@"readyToPlay"])
    {
        keyPaths = [keyPaths setByAddingObject:@"avPlayer.status"];
    }
    
    return keyPaths;
}

@end

/*
 In case we want to loop later: http://stackoverflow.com/questions/5361145/looping-a-video-with-avfoundation-avplayer
 I recommend using AVQueuePlayer to loop your videos seamlessly. Add the notification observer
 
 AVPlayerItemDidPlayToEndTimeNotification
 and in its selector, loop your video
 
 AVPlayerItem *video = [[AVPlayerItem alloc] initWithURL:videoURL];
 [self.player insertItem:video afterItem:nil];
 [self.player play];
 */