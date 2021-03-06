//
//  DLResourceLoader.m
//  DLCachePlayer
//
//  Created by DoubleLight on 2017/11/10.
//  Copyright © 2017年 DoubleLight. All rights reserved.
//

#import "DLResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "DLCachePlayer.h"
#import <GoogleSignIn/GoogleSignIn.h>
#import "TLAudio.h"
#import "TLFlac.h"
#import "gplayer-Swift.h"

#define LOG_LOCK NO

@implementation DLResourceLoader
{
    NSMutableArray * requestList;
    NSOperationQueue * queue;
    NSURLSession * session;
    DLRequestTask * loadingTask;
    NSTimer * retryTimer;
    NSInteger retryCount;
    NSLock * lock;
}
@synthesize tasks, totalLength;
@synthesize finished, canceled, gotMetadata;

- (void)dealloc
{
    [self stopLoading];
}

- (instancetype)init
{
    if (self = [super init])
    {
        requestList = [NSMutableArray array];
        queue = [NSOperationQueue new];
        session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:queue];
        tasks = [NSMutableArray new];
        lock = [NSLock new];
        finished = NO;
        canceled = NO;
        gotMetadata = NO;
    }
    return self;
}

- (void)stopLoading
{
    if (LOG_LOCK) NSLog(@"lock stopLoading");
    [lock lock];
    {
        canceled = YES;
        [loadingTask cancelLoading];
        loadingTask = nil;
        [queue cancelAllOperations];
        queue = nil;
        [session invalidateAndCancel];
        session = nil;
        [tasks removeAllObjects];
        [requestList removeAllObjects];
    }
    if (LOG_LOCK) NSLog(@"unlock stopLoading");
    [lock unlock];
}

#pragma mark - AVAssetResourceLoaderDelegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //NSLog(@"shouldWaitForLoadingOfRequestedResource, offset = %llu, length = %ld", loadingRequest.dataRequest.requestedOffset, (long)loadingRequest.dataRequest.requestedLength);
    if (LOG_LOCK) NSLog(@"lock shouldWaitForLoadingOfRequestedResource");
    [lock lock];
    {
        [self addLoadingRequest:loadingRequest];
    }
    if (LOG_LOCK) NSLog(@"unlock shouldWaitForLoadingOfRequestedResource");
    [lock unlock];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    if (LOG_LOCK) NSLog(@"lock didCancelLoadingRequest");
    [lock lock];
    {
        [requestList removeObject:loadingRequest];
    }
    if (LOG_LOCK) NSLog(@"unlock didCancelLoadingRequest");
    [lock unlock];
}

- (void)requestTaskDidFinishLoadingWithCache:(BOOL)cache data:(NSData *)data url:(NSURL *)url
{
    finished = cache;
    if (finished &&
        self.delegate && [self.delegate respondsToSelector:@selector(loader:loadingSuccess:url:)])
    {
        [self.delegate loader:self loadingSuccess:data url:url];
    }
}

- (void)requestTaskDidFailWithError:(NSError *)error url:(NSURL *)url
{
    if (LOG_LOCK) NSLog(@"unlock requestTaskDidFailWithError");
    [lock unlock];
    if (self.delegate && [self.delegate respondsToSelector:@selector(loader:loadingFailWithError:url:)])
    {
        [self.delegate loader:self loadingFailWithError:error url:url];
    }
    [self stopLoading];
}

- (void)addLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    if (loadingRequest.dataRequest.requestedOffset >= totalLength && totalLength != 0) {
        [loadingRequest finishLoadingWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        return;
    }
    BOOL canCutLine = YES;
    if (loadingRequest.dataRequest.requestsAllDataToEndOfResource)
    {
        for (AVAssetResourceLoadingRequest * request in requestList)
        {
            if (!request.dataRequest.requestsAllDataToEndOfResource)
            {
                canCutLine = NO;
            }
        }
    }
    [requestList addObject:loadingRequest];
    if (finished)
    {
        DLRequestTask * task = [tasks objectAtIndex:0];
        NSError * error;
        task.fileHandle = [NSFileHandle fileHandleForUpdatingURL:task.tempFileURL error:&error];
        if (error)
        {
            [self requestTaskDidFailWithError:error url:loadingRequest.request.URL];
            return;
        }
        [self responseRequestList:task];
        [task.fileHandle closeFile];
        return;
    }
    if (canCutLine)
        [self handleLoadingRequest:loadingRequest];
}
- (void)handleLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    for (int i = 0; i < tasks.count; i++)                                    // 清除尚未有任何進度的 task
    {
        DLRequestTask * task = [tasks objectAtIndex:i];
        if (task.cacheLength == 0)
        {
            [tasks removeObject:task];
            i--;
        }
    }
    [retryTimer invalidate];
    retryTimer = nil;
    DLRequestTask * lastTask = nil;
    for (NSInteger i = tasks.count - 1; i >= 0; i--)
    {
        DLRequestTask * task = [tasks objectAtIndex:i];
        if (loadingRequest.dataRequest.requestedOffset > [task cacheEnd])    // 播放要求位於任一當前 task 之後
        {
            if (lastTask)                                                    // 後面還有其他 task，create 補間 task
            {
                DLRequestTask * newTask = [self startNewTask:[self originSchemeURL:loadingRequest.request.URL] start:loadingRequest.dataRequest.requestedOffset end:lastTask.requestOffset];
                if (newTask)
                    [tasks insertObject:newTask atIndex:i + 1];
                return;
            }
            else                                                             // 後面沒有其他 task，直接 create append
                break;
        }
        else if (loadingRequest.dataRequest.requestedOffset >= task.requestOffset) // 播放要求位於任一當前 task 之中
        {
            NSUInteger requestEnd = loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength;
            if (task.isLoading)
            {
                [self responseRequestList:task];
                return;
            }
            else if (requestEnd <= task.requestEnd) {
                NSError * error;
                task.fileHandle = [NSFileHandle fileHandleForUpdatingURL:task.tempFileURL error:&error];
                [self responseRequestList:task];
                [task.fileHandle closeFile];
                return;
            }
            else
            {
                NSUInteger end = lastTask ? lastTask.requestOffset : 0;
                NSMutableURLRequest * request = [self requestForTask:[self originSchemeURL:loadingRequest.request.URL] start:[task cacheEnd] end:end];
                NSError * error;
                task.fileHandle = [NSFileHandle fileHandleForUpdatingURL:task.tempFileURL error:&error];
                if (error)
                {
                    [self requestTaskDidFailWithError:error url:loadingRequest.request.URL];
                    return;
                }
                task.task = [session dataTaskWithRequest:request];
                [task.task resume];
                task.requestEnd = end;
                loadingTask = task;
                loadingTask.isLoading = YES;
                return;
            }
        }
        lastTask = task;
    }
    DLRequestTask * newTask = [self startNewTask:[self originSchemeURL:loadingRequest.request.URL] start:loadingRequest.dataRequest.requestedOffset end:0];
    [tasks addObject:newTask];
    return;
}

- (NSMutableURLRequest *)requestForTask:(NSURL *)url start:(NSUInteger)start end:(NSUInteger)end
{
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15];
    [request addValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request addValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    //[request addValue:@"org.cocoapods.GoogleAPIClientForREST/1.3.11 google-api-objc-client/3.0 iPhone/12.0.1 hw/iPhone9_3 (gzip)" forHTTPHeaderField:@"User-Agent"];
    if ([url.absoluteString containsString:@"www.googleapis.com/drive"]) {
        //NSString *token = [[[[GIDSignIn sharedInstance] currentUser] authentication] accessToken];
        NSString *token = [[GoogleUtility shared] currentToken];
        [request addValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    }
    if (start > 0)
    {
        if (end == 0)
            [request addValue:[NSString stringWithFormat:@"bytes=%@-", @(start)] forHTTPHeaderField:@"Range"];
        else
            [request addValue:[NSString stringWithFormat:@"bytes=%@-%@", @(start), @(end - 1)] forHTTPHeaderField:@"Range"];
    }
    if (loadingTask)
    {
        [loadingTask cancelLoading];
    }
    return request;
}

- (DLRequestTask *)startNewTask:(NSURL *)url start:(NSUInteger)start end:(NSUInteger)end
{
    NSMutableURLRequest * request = [self requestForTask:url start:start end:end];
    loadingTask = [[DLRequestTask alloc] initWithStart:start end:end];
    loadingTask.tempFileURL = [NSURL URLWithString:[[DLCachePlayer sharedInstance].tempFilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", @(start)]]];
    [[NSFileManager defaultManager] createFileAtPath:loadingTask.tempFileURL.path contents:nil attributes:nil];
    NSError * error;
    loadingTask.fileHandle = [NSFileHandle fileHandleForUpdatingURL:loadingTask.tempFileURL error:&error];
    if (error)
    {
        [self requestTaskDidFailWithError:error url:url];
        return nil;
    }
    loadingTask.task = [session dataTaskWithRequest:request];
    [loadingTask.task resume];
    loadingTask.isLoading = YES;
    return loadingTask;
}

- (NSURL *)originSchemeURL:(NSURL *)url
{
    NSURLComponents * components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = self.originScheme;
    return [components URL];
}

- (void)responseRequestList:(DLRequestTask *)task
{
    if (canceled) return;
    NSMutableArray * finishRequestList = [NSMutableArray array];
    BOOL foundRequest = NO;
    for (AVAssetResourceLoadingRequest * loadingRequest in requestList)
    {
        if (loadingRequest.dataRequest.requestedOffset >= task.requestOffset &&
            loadingRequest.dataRequest.requestedOffset <= [task cacheEnd])
        {
            foundRequest = YES;
            if ([self finishLoadingWithLoadingRequest:loadingRequest task:task])
            {
                [finishRequestList addObject:loadingRequest];
            }
        }
    }
    [requestList removeObjectsInArray:finishRequestList];
    if (!foundRequest && requestList.count != 0)
    {
        [self handleLoadingRequest:[requestList lastObject]];
    }
}

- (BOOL)finishLoadingWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest task:(DLRequestTask *)task
{
    // read file information
    NSString * mimeType = [task.response MIMEType];
    if ([mimeType containsString:@"audio"]) {
        if ([mimeType containsString:@"m4a"]) {
            mimeType = @"audio/x-m4a";
        }
        else if ([mimeType containsString:@"flac"]) {
            mimeType = @"audio/flac";
        }
    }
    //mimeType = @"audio/x-m4a";
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    loadingRequest.contentInformationRequest.contentLength = totalLength;
    if (task.requestEnd == 0)
    {
        task.requestEnd = totalLength;
    }
    
    // respond data
    NSUInteger requestOffset = loadingRequest.dataRequest.requestedOffset;
    if (loadingRequest.dataRequest.currentOffset != 0)
    {
        requestOffset = loadingRequest.dataRequest.currentOffset;
    }
    NSUInteger dataOffset = requestOffset - task.requestOffset;
    NSUInteger canReadLength = task.cacheLength - dataOffset;
    NSUInteger respondLength = MIN(canReadLength, loadingRequest.dataRequest.requestedLength);
    [task.fileHandle seekToFileOffset:dataOffset];
    NSData * data = [task.fileHandle readDataOfLength:respondLength];
    [loadingRequest.dataRequest respondWithData:data];
    
    // cehck request finish
    NSUInteger reqEndOffset = loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength;
    if (loadingRequest.dataRequest.currentOffset >= reqEndOffset)
    {
        [loadingRequest finishLoading];
        return YES;
    }
    return NO;
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    completionHandler(NSURLSessionResponseAllow);
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    NSString * contentRange = [[httpResponse allHeaderFields] objectForKey:@"Content-Range"];
    NSString * fileLength = [[contentRange componentsSeparatedByString:@"/"] lastObject];
    totalLength = fileLength.integerValue > 0 ? fileLength.integerValue : response.expectedContentLength;
    loadingTask.response = httpResponse;
    if (loadingTask.requestEnd == 0) {
        loadingTask.requestEnd = totalLength;
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if (LOG_LOCK) NSLog(@"lock didReceiveData");
    [lock lock];
    {
        for (DLRequestTask * task in tasks)
        {
            if ([task.task isEqual:dataTask])
            {
                if (!task.isLoading)
                {
                    break;
                }
                [task.fileHandle seekToEndOfFile];
                [task.fileHandle writeData:data];
                task.cacheLength += data.length;
                [self responseRequestList:task];
                break;
            }
        }
        if ([self.delegate respondsToSelector:@selector(loader:loadingProgress:totalBytes:)])
        {
            [self.delegate loader:self loadingProgress:tasks totalBytes:totalLength];
        }
        retryCount = 0;
    }
    if (LOG_LOCK) NSLog(@"unlock didReceiveData");
    [lock unlock];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (LOG_LOCK) NSLog(@"lock didCompleteWithError");
    [lock lock];
    {
        for (DLRequestTask * t in tasks)
        {
            if ([t.task isEqual:task])
            {
                t.isLoading = NO;
                [t.fileHandle closeFile];
                break;
            }
        }
    }
    if (LOG_LOCK) NSLog(@"unlock didCompleteWithError");
    [lock unlock];
    if (error)
    {
        if (error.code != NSURLErrorCancelled)
        {
            if (retryCount < [DLCachePlayer sharedInstance].retryTimes)
            {
                retryCount++;
                retryTimer = [NSTimer timerWithTimeInterval:[DLCachePlayer sharedInstance].retryDelay target:self selector:@selector(retryLoading) userInfo:nil repeats:NO];
                [[NSRunLoop mainRunLoop] addTimer:retryTimer forMode:NSDefaultRunLoopMode];
            }
            else
            {
                [self requestTaskDidFailWithError:error url:task.response.URL];
            }
        }
    }
    else
    {
        if (!gotMetadata && self.playerItem.avPlayerItem.asset.commonMetadata.count > 0) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            for (AVMetadataItem *metadata in self.playerItem.avPlayerItem.asset.commonMetadata) {
                [dict setObject:metadata.value forKey:metadata.commonKey];
            }
            self.playerItem.metadata = dict;
            if ([self.delegate respondsToSelector:@selector(loader:gotMetadata:)]) {
                [self.delegate loader:self gotMetadata:dict];
            }
            gotMetadata = YES;
        }
        [lock lock];
        [self mergeTaskData];
        NSData * data = [self finishCacheData];
        if (data)
        {
            [session invalidateAndCancel];
            session = nil;
            [self loadMetadata];
            [self requestTaskDidFinishLoadingWithCache:YES data:data url:task.response.URL];
        }
        else {
            [self loadMetadata];
        }
        [lock unlock];
    }
}

- (void)loadMetadata {
    DLRequestTask *task = [tasks firstObject];
    if ([task.task.response.MIMEType containsString:@"flac"]) {
        NSString *oriPath = task.tempFileURL.path;
        NSString *newPath = [NSString stringWithFormat:@"%@.flac", oriPath];
        NSError *error;
        [[NSFileManager defaultManager] moveItemAtPath:oriPath toPath:newPath error:&error];
        if (!error) {
            TLAudio *tla = [[TLAudio alloc] initWithFileAtPath:newPath];
            NSMutableDictionary *dict = [NSMutableDictionary new];
            if (tla.title.length > 0) {
                [dict setObject:tla.title forKey:@"title"];
            }
            if (tla.artist.length > 0) {
                [dict setObject:tla.artist forKey:@"artist"];
            }
            if (tla.album.length > 0) {
                [dict setObject:tla.album forKey:@"albumName"];
            }
            if (tla.frontCoverPicture.length > 0) {
                [dict setObject:tla.frontCoverPicture forKey:@"artwork"];
            }
            else if (tla.artistPicture.length > 0) {
                [dict setObject:tla.artistPicture forKey:@"artwork"];
            }
            self.playerItem.metadata = dict;
            if ([self.delegate respondsToSelector:@selector(loader:gotMetadata:)]) {
                [self.delegate loader:self gotMetadata:dict];
            }
            gotMetadata = YES;
            [[NSFileManager defaultManager] moveItemAtPath:newPath toPath:oriPath error:&error];
        }
    }
}

- (void)retryLoading
{
    [lock lock];
    if (requestList.count > 0)
    {
        [self handleLoadingRequest:[requestList lastObject]];
    }
    else
    {
        [self finishCacheData];
    }
    [lock unlock];
}

- (void)mergeTaskData
{
    for (NSInteger i = 0; i < tasks.count - 1; i++)
    {
        DLRequestTask * task = [tasks objectAtIndex:i];
        DLRequestTask * nextTask = [tasks objectAtIndex:i + 1];
        if ([task cacheEnd] == nextTask.requestOffset)
        {
            NSURL * fileURL = [NSURL fileURLWithPath:nextTask.tempFileURL.path];
            NSData * data = [NSData dataWithContentsOfURL:fileURL];
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            NSError * error;
            task.fileHandle = [NSFileHandle fileHandleForUpdatingURL:task.tempFileURL error:&error];
            if (error)
            {
                [self requestTaskDidFailWithError:error url:task.task.response.URL];
                return;
            }
            [task.fileHandle seekToEndOfFile];
            [task.fileHandle writeData:data];
            [task.fileHandle closeFile];
            task.cacheLength += nextTask.cacheLength;
            task.requestEnd = nextTask.requestEnd;
            [tasks removeObject:nextTask];
            i--;
        }
    }
}
- (NSData *)finishCacheData
{
    NSURL * url = loadingTask.response.URL;
    NSUInteger offset = 0;
    DLRequestTask * lastTask = nil;
    for (int i = 0; i < tasks.count; i++)
    {
        DLRequestTask * task = [tasks objectAtIndex:i];
        if (offset != task.requestOffset)
        {
            if (!lastTask)
            {
                DLRequestTask * newTask = [self startNewTask:url start:offset end:task.requestOffset];
                if (newTask)
                    [tasks insertObject:newTask atIndex:i];
            }
            else
            {
                NSMutableURLRequest * request = [self requestForTask:url start:offset end:task.requestOffset];
                NSError * error;
                lastTask.fileHandle = [NSFileHandle fileHandleForUpdatingURL:lastTask.tempFileURL error:&error];
                if (error)
                {
                    [self requestTaskDidFailWithError:error url:url];
                    return nil;
                }
                lastTask.task = [session dataTaskWithRequest:request];
                [lastTask.task resume];
                lastTask.requestEnd = task.requestOffset;
                loadingTask = lastTask;
                loadingTask.isLoading = YES;
            }
            return nil;
        }
        offset += task.cacheLength;
        lastTask = task;
    }
    lastTask = [tasks objectAtIndex:0];
    if ([lastTask cacheEnd] != lastTask.requestEnd)
    {
        NSMutableURLRequest * request = [self requestForTask:url start:[lastTask cacheEnd] end:lastTask.requestEnd];
        NSError * error;
        lastTask.fileHandle = [NSFileHandle fileHandleForUpdatingURL:lastTask.tempFileURL error:&error];
        if (error)
        {
            [self requestTaskDidFailWithError:error url:url];
            return nil;
        }
        lastTask.task = [session dataTaskWithRequest:request];
        [lastTask.task resume];
        loadingTask = lastTask;
        loadingTask.isLoading = YES;
        return nil;
    }
    NSURL * fileURL = [NSURL fileURLWithPath:lastTask.tempFileURL.path];
    NSData * data = [NSData dataWithContentsOfURL:fileURL];
    NSString * newName = [NSString stringWithFormat:@"temp%@", @(self.hash)];
    NSURL * newURL = [NSURL URLWithString:[[DLCachePlayer sharedInstance].tempFilePath stringByAppendingPathComponent:newName]];
    NSError * error;
    [[NSFileManager defaultManager] moveItemAtURL:fileURL toURL:[NSURL fileURLWithPath:newURL.path] error:&error];
    if (error)
    {
        [self requestTaskDidFailWithError:error url:url];
        return nil;
    }
    else
    {
        lastTask.tempFileURL = newURL;
    }
    return data;
}

@end

@implementation DLRequestTask

- (void)dealloc
{
    [self cancelLoading];
    NSError * error;
    [[NSFileManager defaultManager] removeItemAtPath:self.tempFileURL.path error:&error];
}

- (instancetype)initWithStart:(NSUInteger)start end:(NSUInteger)end
{
    if (self = [super init])
    {
        self.requestOffset = start;
        self.requestEnd = end;
    }
    return self;
}

- (NSUInteger)cacheEnd
{
    return self.requestOffset + self.cacheLength;
}

- (void)cancelLoading
{
    [self.task cancel];
    self.isLoading = NO;
    [self.fileHandle closeFile];
}

@end
