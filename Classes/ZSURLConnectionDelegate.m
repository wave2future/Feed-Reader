/*
 * URL Delegate Operation
 *
 * Implementation of an image cache that stores downloaded images
 * based on a URL key.  The cache is not persistent (OS makes no
 * guarantees) and is not backed-up when the device is sync'd.
 *
 *  Permission is hereby granted, free of charge, to any person
 *  obtaining a copy of this software and associated documentation
 *  files (the "Software"), to deal in the Software without
 *  restriction, including without limitation the rights to use,
 *  copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following
 *  conditions:
 *
 *  The above copyright notice and this permission notice shall be
 *  included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#import "ZSURLConnectionDelegate.h"

@implementation ZSURLConnectionDelegate

@synthesize isExecuting = executing;
@synthesize isFinished = finished;

@synthesize connection;
@synthesize delegate;
@synthesize successSelector;
@synthesize failureSelector;
@synthesize data;
@synthesize request;
@synthesize statusCode;

- (id)init
{
  if (!(self = [super init])) return nil;
  
  finished = NO;
  executing = NO;
  
  return self;
}

- (void)dealloc
{
  [data release], data = nil;
  [request release], request = nil;
  [super dealloc];
}

- (NSString*)dataString;
{
  NSString *temp = [[NSString alloc] initWithData:[self data] encoding:NSUTF8StringEncoding];
  return [temp autorelease];
}

#pragma mark -
#pragma mark NSOperation methods

- (BOOL)isConcurrent
{
  return YES;
}

- (void)start
{
  DLog(@"%s url %@", __PRETTY_FUNCTION__, [[self request] URL]);
  connection = [NSURLConnection connectionWithRequest:[self request] delegate:self];
  [self willChangeValueForKey:@"isExecuting"];
  executing = YES;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)finish
{
  [self willChangeValueForKey:@"isExecuting"];
  executing = NO;
  [self didChangeValueForKey:@"isExecuting"];
  
  [self willChangeValueForKey:@"isFinished"];
  finished = YES;
  [self didChangeValueForKey:@"isFinished"];
}


#pragma mark -
#pragma mark NSURLConnection methods

- (BOOL)connection:(NSURLConnection*)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace*)protectionSpace
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
  return NO;
}

- (void)connection:(NSURLConnection*)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
}

- (void)connection:(NSURLConnection*)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSHTTPURLResponse*)response
{
  statusCode = [response statusCode];
  data = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data_
{
  [[self data] appendData:data_];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
{
  if ([self successSelector] && [[self delegate] respondsToSelector:[self successSelector]]) {
    [[self delegate] performSelector:[self successSelector] withObject:self];
  }
  [self finish];
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
  if ([self failureSelector] && [[self delegate] respondsToSelector:[self failureSelector]]) {
    [[self delegate] performSelector:[self failureSelector] withObject:self];
  }
  [self finish];
}

@end
