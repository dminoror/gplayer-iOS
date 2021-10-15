//
//  DLCachePlayer.m
//  DLCachePlayer
//
//  Created by DoubleLight on 2017/11/2.
//  Copyright © 2017年 DoubleLight. All rights reserved.
//

#import "DLCachePlayer.h"

@implementation DLCachePlayer
{
    DLResourceLoader * currentLoader;
    DLResourceLoader * preloadLoader;
    DLPlayerItem * loadingPlayerItem;
    NSTimeInterval bufferTime;
}
@synthesize audioPlayer, delegate, tempFilePath;
@synthesize downloadState, playState;

+ (DLCachePlayer *)sharedInstance
{
    static DLCachePlayer * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DLCachePlayer alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.queueDL = dispatch_queue_create("resource_queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
        
        audioPlayer = [[AVPlayer alloc] init];
        if (@available(iOS 10.0, *))
        {
            audioPlayer.automaticallyWaitsToMinimizeStalling = NO;
        }
        downloadState = DLCachePlayerDownloadStateIdle;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemFailedToPlayEndTime:)
                                                     name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemPlaybackStall:)
                                                     name:AVPlayerItemPlaybackStalledNotification
                                                   object:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"rate" options:0 context:nil];
        [self.audioPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        
        self.retryTimes = 3;
        self.retryDelay = 1;
        self.tempFilePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"tmp"] stringByAppendingPathComponent:@"musicCahce"];
        NSArray *tempFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.tempFilePath error:nil];
        for (NSString *tempFile in tempFiles) {
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:[self.tempFilePath stringByAppendingPathComponent:tempFile] error:&error];
        }
    }
    return self;
}

- (void)setDelegate:(NSObject<DLCachePlayerDataDelegate, DLCachePlayerStateDelegate> *)setDelegate
{
    delegate = setDelegate;
}
- (void)setTempFilePath:(NSString *)setTempFilePath
{
    if (self.tempFilePath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
    }
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:setTempFilePath isDirectory:&isDir])
    {
        NSError * error;
        [[NSFileManager defaultManager] createDirectoryAtPath:setTempFilePath withIntermediateDirectories:YES attributes:nil error:&error];
        if (error)
        {
            return;
        }
    }
    tempFilePath = setTempFilePath;
    
}

#pragma mark - Player Method

- (void)resetAndPlay
{
    [self setupCurrentPlayerItem];
}
- (void)pause
{
    if (playState == DLCachePlayerPlayStatePlaying)
    {
        [self.audioPlayer pause];
        [self playerDidPlayStateChanged:DLCachePlayerPlayStatePause];
    }
    if (playState == DLCachePlayerPlayStateBuffering) {
        bufferTime = 0;
    }
}
- (void)resume
{
    [self.audioPlayer play];
}
- (void)stop
{
    [self.audioPlayer pause];
    if (self.audioPlayer.currentItem)
    {
        [self seekToTimeInterval:0 completionHandler:^(BOOL finished) {
            [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
        }];
    }
    else
    {
        [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
    }
}
- (void)seekToTimeInterval:(NSTimeInterval)timeInterval completionHandler:(void (^)(BOOL finished))completionHandler
{
    int32_t timeScale = self.audioPlayer.currentItem.duration.timescale;
    CMTime time = CMTimeMakeWithSeconds(timeInterval, timeScale);
    __block BOOL isPlaying = [self isPlaying];
    if (isPlaying)
        [self pause];
    __block void (^weakBlock)(BOOL finished) = completionHandler;
    __weak DLCachePlayer * weakSelf = self;
    [self.audioPlayer seekToTime:time completionHandler:^(BOOL finished) {
        if (isPlaying)
            [weakSelf resume];
        SAFE_BLOCK(weakBlock, finished);
    }];
}

- (BOOL)isPlaying
{
    return self.audioPlayer.rate != 0.f;
}

- (NSTimeInterval)currentTime
{
    if (self.audioPlayer.currentItem)
    {
        NSTimeInterval time = CMTimeGetSeconds(self.audioPlayer.currentTime);
        if (time == time)  // check isnan
            return time;
    }
    return 0;
}
- (NSTimeInterval)currentDuration
{
    if (self.audioPlayer.currentItem)
    {
        NSTimeInterval time;
        if ([self.audioPlayer.currentItem.asset isKindOfClass:[AVURLAsset class]]) {
            AVURLAsset *asset = (AVURLAsset *)self.audioPlayer.currentItem.asset;
            time = CMTimeGetSeconds(asset.duration);
            if (time == time && time > 0)
                return time;
        }
        time = CMTimeGetSeconds(self.audioPlayer.currentItem.duration);
        if (time == time)
            return time; 
    }
    return 0;
}

- (void)cachedProgress:(AVPlayerItem *)playerItem result:(void (^)(NSMutableArray * tasks, NSUInteger totalBytes))result
{
    if ([playerItem isEqual:currentLoader.playerItem.avPlayerItem])
    {
        SAFE_BLOCK(result, currentLoader.tasks, currentLoader.totalLength);
    }
    else if ([playerItem isEqual:preloadLoader.playerItem.avPlayerItem])
    {
        SAFE_BLOCK(result, preloadLoader.tasks, preloadLoader.totalLength);
    }
    else
    {
        SAFE_BLOCK(result, nil, 0);
    }
}

#pragma mark - Private Method

- (void)setupCurrentPlayerItem
{
    if (!currentLoader.finished)
    {
        [currentLoader stopLoading];
    }
    [audioPlayer replaceCurrentItemWithPlayerItem:nil];
    [self playerDidPlayStateChanged:DLCachePlayerPlayStateInit];
    __weak __typeof__(self) weakSelf = self;
    if ([self.delegate respondsToSelector:@selector(playerGetCurrentPlayerItem:)])
    {
        [self.delegate playerGetCurrentPlayerItem:^DLPlayerItem *(DLPlayerItem *playerItem, BOOL cache) {
            if (playerItem.url.absoluteString.length > 0)
            {
                downloadState = DLCachePlayerDownloadStateCurrent;
                if ([playerItem.url isFileURL] || !cache)
                {
                    AVPlayerItem * avPlayerItem = [AVPlayerItem playerItemWithURL:playerItem.url];
                    [audioPlayer replaceCurrentItemWithPlayerItem:avPlayerItem];
                    [audioPlayer play];
                    [weakSelf setupPreloadPlayerItem];
                    playerItem.avPlayerItem = avPlayerItem;
                    return playerItem;
                }
                else if ([loadingPlayerItem.avPlayerItem.asset isKindOfClass:[AVURLAsset class]] &&
                         [((AVURLAsset *)loadingPlayerItem.avPlayerItem.asset).URL.resourceSpecifier isEqualToString:playerItem.url.resourceSpecifier])
                {
                    currentLoader = ((DLResourceLoader *)((AVURLAsset *)loadingPlayerItem.avPlayerItem.asset).resourceLoader.delegate);
                    [audioPlayer replaceCurrentItemWithPlayerItem:loadingPlayerItem.avPlayerItem];
                    [audioPlayer play];
                    if ([self currentTime] > 0)
                    {
                        [self seekToTimeInterval:0 completionHandler:nil];
                    }
                    id tempPlayerItem = loadingPlayerItem;
                    if (currentLoader.finished)
                    {
                        [weakSelf setupPreloadPlayerItem];
                    }
                    return tempPlayerItem;
                }
                else
                {
                    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[self customSchemeURL:playerItem.url] options:nil];
                    if (!preloadLoader.finished)
                    {
                        [preloadLoader stopLoading];
                    }
                    currentLoader = [[DLResourceLoader alloc] init];
                    currentLoader.originScheme = playerItem.url.scheme;
                    currentLoader.delegate = self;
                    [asset.resourceLoader setDelegate:currentLoader queue:self.queueDL];
                    AVPlayerItem * avPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
                    currentLoader.playerItem = playerItem;
                    currentLoader.playerItem.avPlayerItem = avPlayerItem;
                    loadingPlayerItem = playerItem;
                    [audioPlayer replaceCurrentItemWithPlayerItem:avPlayerItem];
                    [audioPlayer play];
                    return playerItem;
                }
            }
            else
            {
                [weakSelf playerFailToPlay:[NSError errorWithDomain:DLCachePlayerErrorDomain code:DLCachePlayerErrorInvalidURL userInfo:@{ @"info" : @"setupCurrentPlayerItem" }]];
                [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
                return nil;
            }
        }];
    }
}
- (void)setupPreloadPlayerItem
{
    if ([self.delegate respondsToSelector:@selector(playerGetPreloadPlayerItem:)])
    {
        [self.delegate playerGetPreloadPlayerItem:^DLPlayerItem *(DLPlayerItem *playerItem, BOOL cache) {
            if (playerItem.url.absoluteString.length > 0)
            {
                downloadState = DLCachePlayerDownloadStateProload;
                if ([playerItem.url isFileURL] || !cache)
                {
                    AVPlayerItem *avPlayerItem = [AVPlayerItem playerItemWithURL:playerItem.url];
                    playerItem.avPlayerItem = avPlayerItem;
                    return playerItem;
                }
                else if ([loadingPlayerItem.avPlayerItem.asset isKindOfClass:[AVURLAsset class]] &&
                         [((AVURLAsset *)loadingPlayerItem.avPlayerItem.asset).URL.resourceSpecifier isEqualToString:playerItem.url.resourceSpecifier])
                {
                    preloadLoader = ((DLResourceLoader *)((AVURLAsset *)loadingPlayerItem.avPlayerItem.asset).resourceLoader.delegate);
                    return loadingPlayerItem;
                }
                else
                {
                    __block AVURLAsset * asset = [AVURLAsset URLAssetWithURL:[self customSchemeURL:playerItem.url] options:nil];
                    if (!preloadLoader.finished)
                    {
                        [preloadLoader stopLoading];
                    }
                    preloadLoader = [[DLResourceLoader alloc] init];
                    preloadLoader.originScheme = playerItem.url.scheme;
                    preloadLoader.delegate = self;
                    [asset.resourceLoader setDelegate:preloadLoader queue:self.queueDL];
                    AVPlayerItem * avPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
                    preloadLoader.playerItem = playerItem;
                    preloadLoader.playerItem.avPlayerItem = avPlayerItem;
                    loadingPlayerItem = playerItem;
                    loadingPlayerItem.avPlayerItem = avPlayerItem;
                    NSArray * keys = @[@"duration"];
                    //[((AVURLAsset *)avPlayerItem.asset) loadValuesAsynchronouslyForKeys:keys completionHandler:nil];
                    //__block AVURLAsset *asset = avPlayerItem.asset;
                    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
                        NSTimeInterval time = CMTimeGetSeconds(asset.duration);
                        NSLog(@"preload duration = %f, asset = %@", time, asset);
                        
                    }];
                    return playerItem;
                }
            }
            else
            {
                return nil;
            }
        }];
    }
}

- (NSURL *)customSchemeURL:(NSURL *)url
{
    NSURLComponents * components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"cache";
    return [components URL];
}

#pragma mark - DLResourceLoader Delegate

- (void)loader:(DLResourceLoader *)loader loadingSuccess:data url:(NSURL *)url
{
    [self playerDidFinishCache:loadingPlayerItem data:data];
    if (self.downloadState == DLCachePlayerDownloadStateCurrent)
    {
        [self setupPreloadPlayerItem];
    }
    downloadState = DLCachePlayerDownloadStateIdle;
}
- (void)loader:(DLResourceLoader *)loader loadingFailWithError:(NSError *)error url:(NSURL *)url
{
    BOOL isCurrent = [loader isEqual:currentLoader];
    [self playerDidFail:loadingPlayerItem error:error];
    if (!isCurrent)
    {
        loadingPlayerItem = nil;
        [preloadLoader stopLoading];
        preloadLoader = nil;
    }
    downloadState = DLCachePlayerDownloadStateIdle;
}
- (void)loader:(DLResourceLoader *)loader gotMetadata:(NSDictionary *)metadata {
    [self playerGotMetadata:loadingPlayerItem metadata:metadata];
}
- (void)loader:(DLResourceLoader *)loader loadingProgress:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    if ([loader isEqual:currentLoader] && bufferTime > 0) {
        NSTimeInterval bufferSeconds = [[NSDate date] timeIntervalSince1970] - bufferTime;
        NSLog(@"buffer seconds = %f", bufferSeconds);
        if (bufferSeconds > 3) {
            bufferTime = 0;
            [self resume];
        }
    }
    [self playerCacheProgress:loadingPlayerItem tasks:tasks totalBytes:totalBytes];
}


#pragma mark - Player KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (object == self.audioPlayer && [keyPath isEqualToString:@"status"])
    {
        if (self.audioPlayer.status == AVPlayerStatusReadyToPlay)
        {
            //[self.audioPlayer play];
        }
        else if (self.audioPlayer.status == AVPlayerStatusFailed)
        {
            [self playerFailToPlay:self.audioPlayer.error];
        }
    }
    if (object == self.audioPlayer && [keyPath isEqualToString:@"rate"])
    {
        BOOL isPlaying = [self isPlaying];
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay)
        {
            if (isPlaying)
                [self playerDidPlayStateChanged:DLCachePlayerPlayStatePlaying];
        }
        if (!isPlaying && playState == DLCachePlayerPlayStatePlaying) {
            bufferTime = [[NSDate date] timeIntervalSince1970];
            [self playerDidPlayStateChanged:DLCachePlayerPlayStateBuffering];
        }
        [self playerPlayingChanged:isPlaying];
    }
    if (object == self.audioPlayer && [keyPath isEqualToString:@"currentItem"])
    {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        AVPlayerItem *lastPlayerItem = [change objectForKey:NSKeyValueChangeOldKey];
        if (lastPlayerItem != (id)[NSNull null])
        {
            @try {
                [lastPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
                [lastPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
            } @catch(id anException) {
                //do nothing, obviously it wasn't attached because an exception was thrown
            }
        }
        if (newPlayerItem != (id)[NSNull null])
        {
            [newPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
            [newPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            [self playerPlayerItemChanged:newPlayerItem];
        }
    }
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"])
    {
        if (self.audioPlayer.currentItem.status == AVPlayerItemStatusFailed)
        {
            [self playerFailToPlay:self.audioPlayer.currentItem.error];
        }
        else if (self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay)
        {
            if (playState == DLCachePlayerPlayStateInit) {
                [self playerReadyToPlay];
                [self playerDidPlayStateChanged:DLCachePlayerPlayStateReady];
                [self.audioPlayer play];
            }
        }
    }
    /*
     if ([keyPath isEqualToString:@"loadedTimeRanges"] && self.audioPlayer.currentItem)
     {
     NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
     if (timeRanges && [timeRanges count])
     {
     CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
     CMTime time = CMTimeAdd(timerange.start, timerange.duration);
     NSLog(@"loadedRanged = %@", @(time.value / time.timescale));
     //[self playerCurrentItemLoading:time];
     }
     }*/
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    [self playerDidPlayStateChanged:DLCachePlayerPlayStateStop];
    [self playerDidReachEnd:notification.object];
}

- (void)playerItemFailedToPlayEndTime:(NSNotification *)notification
{
}

- (void)playerItemPlaybackStall:(NSNotification *)notification
{
    
}

#pragma mark - Delegate Callback

- (void)playerDidFinishCache:(DLPlayerItem *)playerItem data:(NSData *)data
{
    if ([self.delegate respondsToSelector:@selector(playerDidFinishCache:data:)]) {
        [self.delegate playerDidFinishCache:playerItem data:data];
    }
}
- (void)playerDidFail:(DLPlayerItem *)playerItem error:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(playerDidFail:error:)]) {
        [self.delegate playerDidFail:playerItem error:error];
    }
}
- (void)playerCacheProgress:(DLPlayerItem *)playerItem tasks:(NSMutableArray *)tasks totalBytes:(NSUInteger)totalBytes
{
    if ([self.delegate respondsToSelector:@selector(playerCacheProgress:tasks:totalBytes:)]) {
        [self.delegate playerCacheProgress:playerItem tasks:tasks totalBytes:totalBytes];
    }
}
- (void)playerGotMetadata:(DLPlayerItem *)playerItem metadata:(NSDictionary *)metadata {
    if ([self.delegate respondsToSelector:@selector(playerGotMetadata:metadata:)]) {
        [self.delegate playerGotMetadata:playerItem metadata:metadata];
    }
}

- (void)playerReadyToPlay
{
    if ([self.delegate respondsToSelector:@selector(playerReadyToPlay)])
    {
        [self.delegate playerReadyToPlay];
    }
}
- (void)playerFailToPlay:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(playerFailToPlay:)])
    {
        [self.delegate playerFailToPlay:error];
    }
}
- (void)playerPlayingChanged:(BOOL)isPlaying
{
    if ([self.delegate respondsToSelector:@selector(playerPlayingChanged:)])
    {
        [self.delegate playerPlayingChanged:isPlaying];
    }
}
- (void)playerPlayerItemChanged:(AVPlayerItem *)playerItem
{
    bufferTime = 0;
    if ([self.delegate respondsToSelector:@selector(playerPlayerItemChanged:)])
    {
        [self.delegate playerPlayerItemChanged:playerItem];
    }
}
- (void)playerDidReachEnd:(AVPlayerItem *)playerItem
{
    if ([self.delegate respondsToSelector:@selector(playerDidReachEnd:)])
    {
        [self.delegate playerDidReachEnd:playerItem];
    }
}
- (void)playerDidPlayStateChanged:(DLCachePlayerPlayState)state
{
    playState = state;
    if ([self.delegate respondsToSelector:@selector(playerDidPlayStateChanged:)])
    {
        [self.delegate playerDidPlayStateChanged:playState];
    }
}

@end


@implementation DLPlayerItem

@end
