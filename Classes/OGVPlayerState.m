//
//  OGVPlayerState.m
//  OGVKit
//
//  Created by Brion on 6/13/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//
//

#import "OGVKit.h"

#import "OGVFileInputStream.h"
#import "OGVHTTPInputStream.h"

@interface OGVPlayerState ()

@property (weak) id<OGVPlayerStateDelegate> delegate;

@property OGVInputStream *stream;
@property OGVAudioFeeder *audioFeeder;
@property OGVDecoder *decoder;

@property (readonly) float baseTime;

@property CFTimeInterval initTime; // [self baseTime] at the beginning of timeline counting
@property CFTimeInterval offsetTime; // offset from initTime to 'live' time at the beginning of timeline counting

@property float frameEndTimestamp;
@property float audioPausePosition;

@property BOOL playing;
@property BOOL playAfterLoad;
@property BOOL seeking;
@property BOOL ended;


@end

@implementation OGVPlayerState
{
    dispatch_queue_t decodeQueue;
    dispatch_queue_t delegateQueue;
}

#pragma mark - Public methods

-(instancetype)initWithURL:(NSURL *)URL
                  delegate:(id<OGVPlayerStateDelegate>)aDelegate
{
    return [self initWithInputStream:[OGVInputStream inputStreamWithURL:URL]
                            delegate:aDelegate];
}

-(instancetype)initWithInputStream:(OGVInputStream *)inputStream
                          delegate:(id<OGVPlayerStateDelegate>)aDelegate
{
    return [self initWithInputStream:inputStream
                            delegate:aDelegate
                       delegateQueue:dispatch_get_main_queue()];
}

-(instancetype)initWithInputStream:(OGVInputStream *)inputStream
                          delegate:(id<OGVPlayerStateDelegate>)aDelegate
                     delegateQueue:(dispatch_queue_t)aDelegateQueue
{
    self = [super init];
    if (self) {
        _delegate = aDelegate;
        
        // decode on background thread
        decodeQueue = dispatch_queue_create("OGVKit.Decoder", NULL);
        
        // draw on UI thread
        delegateQueue = aDelegateQueue;
        
        _stream = inputStream;
        _initTime = 0;
        _offsetTime = 0;
        _playing = NO;
        _seeking = NO;
        _playAfterLoad = NO;
        
        _frameEndTimestamp = 0;
        _audioPausePosition = 0;
        
        // Start loading the URL and processing header data
        dispatch_async(decodeQueue, ^() {
            // @todo set our own state to connecting!
            self.stream.delegate = self;
            [self.stream start];
        });
    }
    return self;
}

-(void)play
{
    dispatch_async(decodeQueue, ^() {
        if (self.playing) {
            // Already playing
        } else if (self.ended) {
            self.ended = NO;
            self.playing = YES;
            [self seek:0.0f];
        } else if (self.decoder.dataReady) {
            [self startPlayback:self.decoder.hasAudio ? self.audioPausePosition : self.frameEndTimestamp];
        } else {
            self.playAfterLoad = YES;
        }
    });
}

-(void)pause
{
    dispatch_async(decodeQueue, ^() {
        float newBaseTime = self.baseTime;
        self.offsetTime = self.playbackPosition;
        self.initTime = newBaseTime;
        if (self.audioFeeder) {
            [self stopAudio];
        }
        
        if (self.playing) {
            self.playing = NO;
            [self callDelegateSelector:@selector(ogvPlayerStateDidPause:) sync:NO withBlock:^() {
                [self.delegate ogvPlayerStateDidPause:self];
            }];
        }
    });
}

-(void)cancel
{
    [self pause];
    
    dispatch_async(decodeQueue, ^() {
        if (self.stream) {
            [self.stream cancel];
        }
        self.stream = nil;
        self.decoder = nil;
    });
}

-(void)seek:(float)time
{
    self.ended = NO;
    if (self.seeking) {
        // this feels very hacky!
        [self.decoder.inputStream cancel];
        [self.decoder.inputStream restart];
    }
    dispatch_async(decodeQueue, ^() {
        if (self.decoder && self.decoder.seekable) {
            BOOL wasPlaying = !self.paused;
            if (wasPlaying) {
                [self pause];
            }
            dispatch_async(self->decodeQueue, ^() {
                BOOL ok = [self.decoder seek:time];
                
                if (ok) {
                    // Adjust the offset for the seek
                    self.offsetTime = time;
                    self.initTime = self.baseTime;
                    
                    // Find out the actual time we seeked to!
                    // We may have gone to a keyframe nearby.
                    [self syncAfterSeek:time exact:YES];
                    if (self.decoder.frameReady) {
                        self.frameEndTimestamp = self.decoder.frameTimestamp;
                        self.offsetTime = self.frameEndTimestamp;
                    } else {
                        // probably at end?
                        self.frameEndTimestamp = time;
                    }
                    if (self.decoder.audioReady) {
                        self.audioPausePosition = self.decoder.audioTimestamp;
                        self.offsetTime = self.audioPausePosition;
                    } else {
                        // probably at end?
                        self.audioPausePosition = time;
                    }
                    
                    [self callDelegateSelector:@selector(ogvPlayerStateDidSeek:) sync:NO withBlock:^() {
                        [self.delegate ogvPlayerStateDidSeek:self];
                    }];
                    if (wasPlaying) {
                        [self play];
                    } else if (self.decoder.hasVideo) {
                        // Show where we left off
                        if ([self.decoder decodeFrame]) {
                            [self drawFrame];
                        }
                    }
                }
            });
        }
    });
}


#pragma mark - getters/setters

-(BOOL)paused
{
    return !self.playing;
}

-(float)playbackPosition
{
    double position = 0.0;
    if (self.playing) {
        position = self.baseTime - self.initTime + self.offsetTime;
    } else {
        position = self.offsetTime;
    }
    
    return (position > 0.0) ? position : 0.0;
}

- (float)baseTime
{
    if (self.decoder.hasAudio && self.audioFeeder) {
        return self.audioFeeder.playbackPosition;
    } else {
        return CACurrentMediaTime();
    }
}

-(float)duration
{
    if (self.decoder) {
        return self.decoder.duration;
    } else {
        return INFINITY;
    }
}

-(BOOL)seekable
{
    if (self.decoder) {
        return self.decoder.seekable;
    } else {
        return NO;
    }
}

#pragma mark - Private decode thread methods

- (void)callDelegateSelector:(SEL)selector sync:(BOOL)sync withBlock:(void(^)(void))block
{
    if ([self.delegate respondsToSelector:selector]) {
        if (delegateQueue) {
            if (sync) {
                dispatch_sync(delegateQueue, block);
            } else {
                dispatch_async(delegateQueue, block);
            }
        } else {
            block();
        }
    }
}

- (void)startDecoder
{
    self.decoder = [[OGVKit singleton] decoderForType:self.stream.mediaType];
    if (self.decoder) {
        // Hand the stream off to the decoder and goooooo!
        self.decoder.inputStream = self.stream;
        [self processHeaders];
    } else {
        [OGVKit.singleton.logger fatalWithFormat:@"no decoder, this should not happen"];
        abort();
    }
    // @fixme update our state
}

- (void)startPlayback:(float)offset
{
    assert(self.decoder.dataReady);
    assert(offset >= 0);
    
    self.playing = YES;
    
    [self initPlaybackState:offset];
    
    if (self.decoder.hasAudio) {
        [self startAudio:offset];
    }
    
    [self callDelegateSelector:@selector(ogvPlayerStateDidPlay:) sync:NO withBlock:^() {
        [self.delegate ogvPlayerStateDidPlay:self];
    }];
    [self pingProcessing:0];
}

- (void)initPlaybackState:(float)offset
{
    assert(self.decoder.dataReady);
    assert(offset >= 0);
    
    self.frameEndTimestamp = 0.0f;
    self.initTime = self.baseTime;
    self.offsetTime = offset;
}

-(void)startAudio:(float)offset
{
    assert(self.decoder.hasAudio);
    assert(!self.audioFeeder);
    
    self.audioFeeder = [[OGVAudioFeeder alloc] initWithFormat:self.decoder.audioFormat];
    
    // Reset to audio clock
    self.initTime = self.baseTime;
    self.offsetTime = offset;
}

-(void)stopAudio
{
    assert(self.decoder.hasAudio);
    assert(self.audioFeeder);
    
    // Save the actual audio time as last offset
    self.audioPausePosition = [self.audioFeeder bufferTailPosition] - self.initTime + self.offsetTime;
    
    // @fixme let the already-queued audio play out when pausing?
    [self.audioFeeder close];
    self.audioFeeder = nil;
    
    // Reset to generic media clock
    self.initTime = self.baseTime;
    self.offsetTime = self.audioPausePosition;
}

- (void)processHeaders
{
    BOOL ok = [self.decoder process];
    if (ok) {
        if (self.decoder.dataReady) {
            [self callDelegateSelector:@selector(ogvPlayerStateDidLoadMetadata:) sync:NO withBlock:^() {
                [self.delegate ogvPlayerStateDidLoadMetadata:self];
            }];
            if (self.playAfterLoad) {
                self.playAfterLoad = NO;
                [self startPlayback:0];
            }
        } else {
            dispatch_async(decodeQueue, ^() {
                [self processHeaders];
            });
        }
    } else {
        [OGVKit.singleton.logger errorWithFormat:@"Error processing header state. :("];
    }
}

- (void)processNextFrame
{
    BOOL more;
    if (!self.playing) {
        return;
    }
    while (true) {
        more = [self.decoder process];
        if (!more) {
            if (self.decoder.inputStream.state == OGVInputStreamStateFailed) {
                [OGVKit.singleton.logger errorWithFormat:@"Hey! The input stream failed. Handle this more gracefully."];
                [self pause];
                self.playing = NO;
                return;
            }
            
            if ((!self.decoder.hasAudio || self.decoder.audioReady) && (!self.decoder.hasVideo || self.decoder.frameReady)) {
                // More packets already demuxed, just keep running them.
            } else {
                // Wait for audio to run out, then close up shop!
                float timeLeft;
                if (self.audioFeeder && [self.audioFeeder isStarted]) {
                    // @fixme if we haven't started and there's time left,
                    // we should trigger actual playback and pad the buffer.
                    timeLeft = [self.audioFeeder timeAwaitingPlayback];
                } else {
                    timeLeft = 0;
                }
                [OGVKit.singleton.logger debugWithFormat:@"ended? time left %f", timeLeft];
                if (timeLeft > 0) {
                    [self pingProcessing:timeLeft];
                } else {
                    [self pause];
                    self.ended = YES;
                    [self callDelegateSelector:@selector(ogvPlayerStateDidEnd:) sync:NO withBlock:^() {
                        [self.delegate ogvPlayerStateDidEnd:self];
                    }];
                }
                return;
            }
        }
        
        float nextDelay = INFINITY;
        float playbackPosition = self.playbackPosition;
        float frameDelay = (self.frameEndTimestamp - playbackPosition);
        
        // See if the frame timestamp is behind the playhead
        BOOL readyToDecodeFrame = (frameDelay <= 0.0);
        
        
        if (self.decoder.hasAudio) {
            
            if ([self.audioFeeder isClosed]) {
                // Switch to raw clock when audio is done.
                [self stopAudio];
            }
            
            if (self.decoder.audioReady) {
                // Drive on the audio clock!
                const float audioTimestamp = self.decoder.audioTimestamp;
                if (!self.audioFeeder) {
                    [self startAudio:audioTimestamp];
                }
                
                const int bufferSize = 8192 * 4; // fake
                const float bufferDuration = (float)bufferSize / self.decoder.audioFormat.sampleRate;
                
                float audioBufferedDuration = [self.audioFeeder secondsQueued];
                BOOL readyForAudio = (audioBufferedDuration <= bufferDuration);
                
                if (readyForAudio) {
                    BOOL ok = [self.decoder decodeAudio];
                    if (ok) {
                        OGVAudioBuffer *audioBuffer = [self.decoder audioBuffer];
                        if (![self.audioFeeder bufferData:audioBuffer]) {
                            if ([self.audioFeeder isClosed]) {
                                // Audio died, perhaps due to starvation during slow decodes
                                // or something else unexpected. Close it out and we'll start
                                // up a new one.
                                [OGVKit.singleton.logger debugWithFormat:@"CLOSING OUT CLOSED AUDIO FEEDER"];
                                [self stopAudio];
                                [self startAudio:audioTimestamp];
                                [self.audioFeeder bufferData:audioBuffer];
                            }
                        }
                        // Go back around the loop in case we need more
                        continue;
                    } else {
                        [OGVKit.singleton.logger errorWithFormat:@"Bad audio packet or something"];
                    }
                }
                
                if (audioBufferedDuration <= bufferDuration) {
                    // NEED MOAR BUFFERS
                    nextDelay = 0;
                } else {
                    // Check in when the audio buffer runs low again...
                    nextDelay = fminf(nextDelay, fmaxf(audioBufferedDuration - bufferDuration / 2.0f, 0.0f));
                }
            } else {
                // Need to find some more packets
                continue;
            }
            
        }
        
        if (self.decoder.hasVideo) {
            if (self.decoder.frameReady) {
                if (readyToDecodeFrame) {
                    BOOL ok = [self.decoder decodeFrame];
                    if (ok) {
                        // Check if it's time to draw (AKA the frame timestamp is at or past the playhead)
                        // If we're already playing, DRAW!
                        [self drawFrame];
                        
                        // End the processing loop, we'll ping again after drawing
                        //return;
                    } else {
                        [OGVKit.singleton.logger errorWithFormat:@"Bad video packet or something"];
                        continue;
                    }
                }
                nextDelay = fminf(nextDelay, fmaxf(self.frameEndTimestamp - playbackPosition, 0.0f));
            } else if (!self.playing) {
                // We're all caught up but paused, will be pinged when played
                return;
            } else {
                // Need more processing; continue the loop
                continue;
            }
        }
        
        if (nextDelay < INFINITY) {
            [self pingProcessing:nextDelay];
            
            // End the processing loop and wait for next ping.
            return;
        } else {
            // nothing to do?
            [OGVKit.singleton.logger errorWithFormat:@"loop drop?"];
            return;
        }
        
        // End the processing loop and wait for next ping.
        return;
    }
}

- (void)pingProcessing:(float)delay
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(popTime, decodeQueue, ^() {
        [self processNextFrame];
    });
}

/**
 * Dequeue frame and schedule a frame draw on the main thread
 */
-(void)drawFrame
{
    OGVVideoBuffer *buffer = self.decoder.frameBuffer;
    self.frameEndTimestamp = buffer.timestamp;
    // Note: this must be sync because memory may belong to the decoder!
    [self callDelegateSelector:@selector(ogvPlayerState:drawFrame:) sync:YES withBlock:^() {
        [self.delegate ogvPlayerState:self drawFrame:buffer];
    }];
}

-(BOOL)syncAfterSeek:(float)target exact:(BOOL)exact
{
    while (YES) {
        while ((self.decoder.hasAudio && !self.decoder.audioReady) || (self.decoder.hasVideo && !self.decoder.frameReady)) {
            if (![self.decoder process]) {
                [OGVKit.singleton.logger errorWithFormat:@"Got to end of file before found data again after seek."];
                return NO;
            }
        }
        if (exact) {
            if (self.decoder.hasAudio && self.decoder.audioReady && self.decoder.audioTimestamp < target) {
                if ([self.decoder decodeAudio]) {
                    // no-op
                }
            }
            if (self.decoder.hasVideo && self.decoder.frameReady && self.decoder.frameTimestamp < target) {
                if ([self.decoder decodeFrame]) {
                    // no-op
                }
            }
            if ((!self.decoder.hasVideo || self.decoder.frameTimestamp >= target) &&
                (!self.decoder.hasAudio || self.decoder.audioTimestamp >= target)) {
                return YES;
            }
        } else {
            // We're ok leaving off after the keyframe
            return YES;
        }
    }
}

#pragma mark - OGVInputStreamDelegate methods

-(void)OGVInputStreamStateChanged:(OGVInputStream *)sender
{
    switch (self.stream.state) {
        case OGVInputStreamStateConnecting:
            // Good... Good. Let the data flow through you!
            break;
            
        case OGVInputStreamStateReading:
            // Break the stream off from us and send it to the decoder.
            self.stream.delegate = nil;
            [self startDecoder];
            break;
            
        case OGVInputStreamStateFailed:
            [OGVKit.singleton.logger errorWithFormat:@"Stream file failed."];
            self.stream.delegate = nil;
            [self.stream cancel];
            self.stream = nil;
            break;
            
        case OGVInputStreamStateCanceled:
            // we canceled it, eh
            break;
            
        default:
            [OGVKit.singleton.logger errorWithFormat:@"Unexpected stream state change! %d", (int)self.stream.state];
            self.stream.delegate = nil;
            [self.stream cancel];
            self.stream = nil;
    }
}

-(void)OGVInputStream:(OGVInputStream *)sender customizeURLRequest:(NSMutableURLRequest *)request
{
    [self callDelegateSelector:@selector(ogvPlayerState:customizeURLRequest:) sync:YES withBlock:^() {
        [self.delegate ogvPlayerState:self customizeURLRequest:request];
    }];
}

@end
