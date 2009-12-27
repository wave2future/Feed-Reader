#import "RootViewController.h"
#import "AppDelegate.h"

@implementation RootViewController

@synthesize fetchedResultsController, managedObjectContext;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  [self setTitle:@"Feed"];
  
  id appDelegate = [[UIApplication sharedApplication] delegate];
  UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                          target:appDelegate
                                                                          action:@selector(refreshFeed:)];
  [[self navigationItem] setRightBarButtonItem:button];
  [button release], button = nil;
	
	NSError *error = nil;
  [[self fetchedResultsController] performFetch:&error];
  ZAssert(error == nil, @"Failed to retrieve results: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark Table view methods

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath
{
	NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
	[[cell textLabel] setText:[[managedObject valueForKey:@"title"] description]];
  [[cell detailTextLabel] setText:[[managedObject valueForKey:@"author"] description]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView 
{
  return [[fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section 
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath 
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
  if (!cell) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                   reuseIdentifier:kCellIdentifier] autorelease];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
  }
  
	[self configureCell:cell atIndexPath:indexPath];
  
  return cell;
}

- (void)tableView:(UITableView*)tableView 
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
forRowAtIndexPath:(NSIndexPath*)indexPath 
{
  
  if (editingStyle != UITableViewCellEditingStyleDelete) return;
  
  // Delete the managed object for the given index path
  NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
  [context deleteObject:[fetchedResultsController objectAtIndexPath:indexPath]];
  
  // Save the context.
  NSError *error = nil;
  [context save:&error];
  ZAssert(error == nil, @"Error saving context: %@", [error localizedDescription]);
}

- (BOOL)tableView:(UITableView*)tableView canMoveRowAtIndexPath:(NSIndexPath*)indexPath 
{
  return NO;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
  
  id controller = [[UIViewController alloc] init];
  [controller setTitle:[managedObject valueForKey:@"title"]];
  
  UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
  [webView setScalesPageToFit:YES];
  
  UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:webView action:@selector(reload)];
  [[controller navigationItem] setRightBarButtonItem:button animated:YES];
  [button release], button = nil;
  
  [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[managedObject valueForKey:@"link"]]]];
  [controller setView:webView];
  
  [[self navigationController] pushViewController:controller animated:YES];
  
  [webView release], webView = nil;
  [controller release], controller = nil;
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController*)fetchedResultsController 
{
  if (fetchedResultsController) return fetchedResultsController;
  
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"FeedItem" 
                                            inManagedObjectContext:[self managedObjectContext]];
	[fetchRequest setEntity:entity];
	
	[fetchRequest setFetchBatchSize:20];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"pubDate" ascending:NO];
	NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
	
	[fetchRequest setSortDescriptors:sortDescriptors];
	
	fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                 managedObjectContext:[self managedObjectContext] 
                                                                   sectionNameKeyPath:nil 
                                                                            cacheName:@"Root"];
  [fetchedResultsController setDelegate:self];
	
	[fetchRequest release], fetchRequest = nil;
  [sortDescriptor release], sortDescriptor = nil;
	[sortDescriptors release], sortDescriptors = nil;
	
	return fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController*)controller 
{
  [[self tableView] beginUpdates];
}

- (void)controller:(NSFetchedResultsController*)controller 
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo 
           atIndex:(NSUInteger)sectionIndex 
     forChangeType:(NSFetchedResultsChangeType)type 
{
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [[self tableView] insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] 
                      withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeDelete:
      [[self tableView] deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controller:(NSFetchedResultsController*)controller 
   didChangeObject:(id)anObject 
       atIndexPath:(NSIndexPath*)indexPath 
     forChangeType:(NSFetchedResultsChangeType)type 
      newIndexPath:(NSIndexPath*)newIndexPath 
{
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeDelete:
      [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeUpdate:
      [self configureCell:[[self tableView] cellForRowAtIndexPath:indexPath]
              atIndexPath:indexPath];
      break;
    case NSFetchedResultsChangeMove:
      [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
      [[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
      break;
  }  
}

- (void)controllerDidChangeContent:(NSFetchedResultsController*)controller 
{
  [[self tableView] endUpdates];
} 

#pragma mark -
#pragma mark Memory management

- (void)dealloc 
{
	[fetchedResultsController release];
	[managedObjectContext release];
  [super dealloc];
}

@end