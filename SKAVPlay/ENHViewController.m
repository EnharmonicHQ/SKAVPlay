//
//  ENHViewController.m
//  SKAVPlay
//
//  Created by Jonathan Saggau on 6/18/14.
//  Copyright (c) 2014 Jonathan Saggau. All rights reserved.
//

#import "ENHViewController.h"
#import "ENHMyScene.h"
#import "ENHExtendedSKVideoNode.h"

@interface ENHViewController ()

@property(nonatomic, weak)IBOutlet UIButton *playPauseButton;
@property(nonatomic, weak)IBOutlet UISlider *positionSlider;
@property(nonatomic, weak)IBOutlet UILabel *positionLabel;
@property(nonatomic, weak)IBOutlet UILabel *speedLabel;

@end

@implementation ENHViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
    SKView * skView = [self skView];
    [skView setShowsFPS:YES];
    [skView setShowsNodeCount:YES];

    // Create and configure the scene.
    ENHMyScene * scene = [ENHMyScene sceneWithSize:skView.bounds.size];

    // Present the scene.
    [skView presentScene:scene];
    [self observeScene];

    [self.playPauseButton setTitle:@"(Not ready)" forState:UIControlStateDisabled];
    [self.playPauseButton setEnabled:scene.videoNode.readyToPlay];
    [self topSliderSlid:self.positionSlider];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(threeFingerTap:)];
    [tap setNumberOfTouchesRequired:3];
    [self.view addGestureRecognizer:tap];
}

-(void)threeFingerTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized)
    {
        SKView *view = (id)self.view;
        ENHMyScene *scene = (id)view.scene;
        ENHExtendedSKVideoNode *videoNode = scene.videoNode;
        if (![videoNode actionForKey:@"spinny"])
        {
            SKAction *scaleAction = [SKAction scaleBy:0.25 duration:2.0];
            SKAction *spinAction = [SKAction rotateByAngle:2*M_PI duration:2.0];
            SKAction *group = [SKAction group:@[scaleAction, spinAction]];
            SKAction *reverse = [group reversedAction];
            SKAction *sequence = [SKAction sequence:@[group, reverse]];
            [videoNode runAction:sequence withKey:@"spinny"];
        }
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

#pragma mark - actions

-(IBAction)topSliderSlid:(UISlider *)sender
{
    //    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self.scene.videoNode setNormalizedPlaybackPosition:sender.value];
}

- (IBAction)playButtonTapped:(UIButton *)sender
{
    if (![self.scene.videoNode playing])
    {
        [self.scene.videoNode play];
        [self.playPauseButton setTitle:@"Pause" forState:UIControlStateNormal];
    }
    else
    {
        [self.scene.videoNode pause];
        [self.playPauseButton setTitle:@"Play" forState:UIControlStateNormal];
    }
}

#pragma mark - Convenience

-(SKView *)skView
{
    return (SKView *)self.view;
}

-(ENHMyScene *)scene
{
    return (id)[self.skView scene];
}

#pragma mark - timeObservation


#pragma mark - KVO

static NSString *kENHViewControllerPlaybackPositionKeypath = @"scene.videoNode.playbackPosition";
static NSString *kENHViewControllerPlaybackPositionContext = @"kENHViewControllerPlaybackPositionContext";

static NSString *kENHViewControllerPlaybackSpeedKeypath = @"scene.videoNode.playbackRate";
static NSString *kENHViewControllerPlaybackSpeedContext = @"kENHViewControllerPlaybackSpeedContext";

static NSString *kENHViewControllerPlayerIsReadyKeypath = @"scene.videoNode.readyToPlay";
static NSString *kENHViewControllerPlayerIsReadyContext = @"kENHViewControllerPlayerIsReadyContext";

-(void)observeScene
{
    [self.scene addObserver:self
                 forKeyPath:kENHViewControllerPlaybackPositionKeypath
                    options:NSKeyValueObservingOptionNew
                    context:&kENHViewControllerPlaybackPositionContext];
    [self.scene addObserver:self
                 forKeyPath:kENHViewControllerPlayerIsReadyKeypath
                    options:NSKeyValueObservingOptionNew
                    context:&kENHViewControllerPlayerIsReadyContext];
    [self.scene addObserver:self
                 forKeyPath:kENHViewControllerPlaybackSpeedKeypath
                    options:NSKeyValueObservingOptionNew
                    context:&kENHViewControllerPlaybackSpeedContext];
}

-(void)unobserveScene
{
    @try {
        [self.scene removeObserver:self
                        forKeyPath:kENHViewControllerPlaybackPositionKeypath];
        [self.scene removeObserver:self
                        forKeyPath:kENHViewControllerPlayerIsReadyKeypath];
        [self.scene removeObserver:self
                        forKeyPath:kENHViewControllerPlaybackSpeedKeypath];
    }
    @catch (NSException *exception) { }
    @finally { }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //    NSLog(@"%@ %@ %@", self, NSStringFromSelector(_cmd), [[NSThread currentThread] isMainThread] ? @"Main thread" : @"Background thread");
    if (context == &kENHViewControllerPlayerIsReadyContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL ready = [self.scene.videoNode readyToPlay];
            [self.playPauseButton setEnabled:ready];
            //            NSLog(@"Ready to play? %@", ready ? @"YES" : @"NO");
        });
    }
    else if (context == &kENHViewControllerPlaybackPositionContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{

            Float32 position = [self.scene.videoNode normalizedPlaybackPosition];
            [self.positionSlider setValue:position];
            //        NSLog(@"Normalized playback position %@", @(position));

            position = [self.scene.videoNode playbackPosition];
            [self.positionLabel setText:[NSString stringWithFormat:@"Pos: %@", @(position)]];
            //        NSLog(@"Playback position %@", @(position));
        });
    }
    else if (context == &kENHViewControllerPlaybackSpeedContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.scene.videoNode seekInProgress])
            {
                float rate = [self.scene.videoNode playbackRate];
                [self.speedLabel setText:[NSString stringWithFormat:@"Spd: %@", @(rate)]];
                if (rate != 0.0)
                {
                    [self.playPauseButton setTitle:@"Pause" forState:UIControlStateNormal];
                }
                else
                {
                    [self.playPauseButton setTitle:@"Play" forState:UIControlStateNormal];
                }
            }
        });
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

-(void)dealloc
{
    [self unobserveScene];
}

@end
