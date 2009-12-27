#import "AppDelegate.h"
#import "RootViewController.h"
#import "ZSURLConnectionDelegate.h"

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

static NSInteger networkActivityCount;
static NSDateFormatter *pubDateFormatter;

+ (void)initialize
{
  pubDateFormatter = [[NSDateFormatter alloc] init];
  [pubDateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
  [pubDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
}

+ (void)incrementNetworkActivity:(id)sender;
{
  ++networkActivityCount;
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

+ (void)decrementNetworkActivity:(id)sender;
{
  --networkActivityCount;
  if (networkActivityCount <= 0) [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  networkActivityCount = 0;
}

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication*)application 
{
  queue = [[NSOperationQueue alloc] init];
  
	id rootViewController = [navigationController topViewController];
	[rootViewController setManagedObjectContext:[self managedObjectContext]];
	
	[window addSubview:[navigationController view]];
  [window makeKeyAndVisible];
}

- (void)applicationWillTerminate:(UIApplication*)application 
{
  if (!managedObjectContext) return;
  if (![managedObjectContext hasChanges]) return;
  NSError *error = nil;
  [managedObjectContext save:&error];
  ZAssert(error == nil, @"Error saving context: %@", [error localizedDescription]);
}

- (void)refreshFeed:(id)sender
{
  NSURL *feedURL = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:kFeedURL]];
  NSURLRequest *request = [NSURLRequest requestWithURL:feedURL];
  
  ZSURLConnectionDelegate *op = [[ZSURLConnectionDelegate alloc] init];
  [op setRequest:request];
  [op setDelegate:self];
  [op setSuccessSelector:@selector(feedSuccess:)];
  [op setFailureSelector:@selector(feedFailure:)];
  
  [AppDelegate incrementNetworkActivity:self];
  [queue addOperation:op];
  [op release], op = nil;
}

- (void)feedFailure:(ZSURLConnectionDelegate*)delegate
{
  [AppDelegate decrementNetworkActivity:self];
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Error" message:[NSString stringWithFormat:@"Failed to retrieve feed: %i\n%@", [delegate statusCode], [delegate dataString]] delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
  [alert show];
  [alert release], alert = nil;
}

- (void)feedSuccess:(ZSURLConnectionDelegate*)delegate
{
  if ([delegate statusCode] != 200) {
    [self feedFailure:delegate];
    return;
  }
  [AppDelegate decrementNetworkActivity:self];
  
  NSError *error = nil;
  CXMLDocument *document = [[CXMLDocument alloc] initWithData:[delegate data] options:0 error:&error];
  ZAssert(error == nil,@"Error creating document from feed: %@", [error localizedDescription]);
  
  NSManagedObjectContext *moc = [self managedObjectContext];
  
  CXMLElement *root = [document rootElement];
  CXMLElement *channel = [[root elementsForName:@"channel"] lastObject];
  
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  [request setEntity:[NSEntityDescription entityForName:@"FeedItem" inManagedObjectContext:moc]];
  
  for (CXMLElement *item in [channel elementsForName:@"item"]) {
    CXMLElement *guidElement = [[item elementsForName:@"guid"] lastObject];
    ZAssert(guidElement != nil, @"item is missing GUID\n%@\n", guidElement);
    [request setPredicate:[NSPredicate predicateWithFormat:@"guid == %@", [guidElement stringValue]]];
    
    NSManagedObject *feedItem = [[moc executeFetchRequest:request error:&error] lastObject];
    ZAssert(error == nil, @"Error accessing context: %@", [error localizedDescription]);
    
    if (!feedItem) {
      feedItem = [NSEntityDescription insertNewObjectForEntityForName:@"FeedItem" inManagedObjectContext:moc];
      [feedItem setValue:[guidElement stringValue] forKey:@"guid"];
    }
    
    [feedItem setValue:[[[item elementsForName:@"author"] lastObject] stringValue] forKey:@"author"];
    [feedItem setValue:[[[item elementsForName:@"category"] lastObject] stringValue] forKey:@"category"];
    [feedItem setValue:[[[item elementsForName:@"desc"] lastObject] stringValue] forKey:@"desc"];
    [feedItem setValue:[[[item elementsForName:@"link"] lastObject] stringValue] forKey:@"link"];
    [feedItem setValue:[[[item elementsForName:@"title"] lastObject] stringValue] forKey:@"title"];
    
    NSString *pubDateString = [[[item elementsForName:@"pubDate"] lastObject] stringValue];
    ZAssert(pubDateString != nil, @"Missing publication date\n%@\n", item);
    [feedItem setValue:[pubDateFormatter dateFromString:pubDateString] forKey:@"pubDate"];
  }
  
  [moc save:&error];
  ZAssert(error == nil, @"Error saving context: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark Core Data stack

- (NSManagedObjectContext*) managedObjectContext 
{
  if (managedObjectContext) return managedObjectContext;
	
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  ZAssert(coordinator != nil, @"Coordinator is nil");
  
  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator: coordinator];
  return managedObjectContext;
}

- (NSManagedObjectModel*)managedObjectModel 
{
  if (managedObjectModel) return managedObjectModel;
  
  managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
  ZAssert(managedObjectModel != nil, @"Managed Object Model is nil");
  
  return managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator 
{
  if (persistentStoreCoordinator) return persistentStoreCoordinator;
	
  NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"Test.sqlite"]];
  
  persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  
	NSError *error = nil;
  [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error];
  ZAssert(error == nil, @"Error adding PSC: %@", [error localizedDescription]);
  
  return persistentStoreCoordinator;
}

#pragma mark -
#pragma mark Application's Documents directory

- (NSString*)applicationDocumentsDirectory 
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

@end