@interface AppDelegate : NSObject <UIApplicationDelegate> 
{
  NSManagedObjectModel *managedObjectModel;
  NSManagedObjectContext *managedObjectContext;	    
  NSPersistentStoreCoordinator *persistentStoreCoordinator;
  
  UIWindow *window;
  UINavigationController *navigationController;
  
  NSOperationQueue *queue;
}

@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

- (NSString*)applicationDocumentsDirectory;
- (void)refreshFeed:(id)sender;

+ (void)incrementNetworkActivity:(id)sender;
+ (void)decrementNetworkActivity:(id)sender;

@end