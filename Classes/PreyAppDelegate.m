//
//  PreyAppDelegate.m
//  Prey-iOS
//
//  Created by Carlos Yaconi on 29/09/2010.
//  Copyright 2010 Fork Ltd. All rights reserved.
//  License: GPLv3
//  Full license at "/LICENSE"

#import "PreyAppDelegate.h"
#import "LoginController.h"
#import "OldUserController.h"
#import "NewUserController.h"
#import "WelcomeController.h"
#import "PreyConfig.h"
#import "CongratulationsController.h"
#import "PreferencesController.h"
#import "Constants.h"
#import "AlertModuleController.h"
#import "FakeWebView.h"
#import "PicturesController.h"
#import "IAPHelper.h"
#import "GAI.h"
#import "PreyDeployment.h"
#import "WizardController.h"
#import "ReportModule.h"
#import "AlertModule.h"
#import "Constants.h"
#import "PreyRestHttp.h"

@interface PreyAppDelegate()

-(void)renderFirstScreen;

@end

@implementation PreyAppDelegate

@synthesize window,viewController;

-(void)renderFirstScreen{

	
}

#pragma mark -
#pragma mark Some useful stuff
- (void)registerForRemoteNotifications {
    PreyLogMessage(@"App Delegate", 10, @"Registering for push notifications...");    
    [[UIApplication sharedApplication] 
	 registerForRemoteNotificationTypes:
	 (UIRemoteNotificationTypeAlert | 
	  UIRemoteNotificationTypeBadge | 
	  UIRemoteNotificationTypeSound)];
}

- (void)changeShowFakeScreen:(BOOL)value
{
    showFakeScreen = value;
}

- (void)showFakeScreen
{
    PreyLogMessage(@"App Delegate", 20,  @"Showing the guy our fake screen at: %@", self.url );
    
    CGRect appFrame = [[UIScreen mainScreen] applicationFrame];
    fakeView = [[[UIWebView alloc] initWithFrame:CGRectMake(0, 0, appFrame.size.width, appFrame.size.height)] autorelease];
    [fakeView setDelegate:self];
    
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:[NSURL URLWithString:self.url]];
    [fakeView loadRequest:requestObj];
    
    UIViewController *fakeViewController = [[UIViewController alloc] init];
    [fakeViewController.view addSubview:fakeView];
    
    [window setRootViewController:fakeViewController];
    [window makeKeyAndVisible];
}

- (void) displayAlert
{
    AlertModuleController *alertController;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        alertController = [[AlertModuleController alloc] initWithNibName:@"AlertModuleController-iPhone" bundle:nil];
    else
        alertController = [[AlertModuleController alloc] initWithNibName:@"AlertModuleController-iPad" bundle:nil];
    
    [alertController setTextToShow:self.alertMessage];
    PreyLogMessage(@"App Delegate", 20, @"Displaying the alert message");
    
    [window setRootViewController:alertController];
    [window makeKeyAndVisible];
    
    [alertController release];
    
    AlertModule *alertModule = [[[AlertModule alloc] init] autorelease];
    [alertModule notifyCommandResponse:[alertModule getName] withStatus:@"started"];
    
    
    showAlert = NO;
}


- (void)showAlert: (NSString *) textToShow {
    self.alertMessage = textToShow;
	showAlert = YES;
}

#pragma mark -
#pragma mark WebView delegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
    PreyLogMessage(@"App Delegate", 20,  @"Attempting to show the HUD");
    
    MBProgressHUD *HUD2 = [MBProgressHUD showHUDAddedTo:webView animated:YES];
    HUD2.labelText = NSLocalizedString(@"Accessing your account...",nil);
    HUD2.removeFromSuperViewOnHide=YES;
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [MBProgressHUD hideHUDForView:webView animated:YES];
    if (showAlert){
        [self displayAlert];
        return;
    }

}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Google Analytics config
    [GAI sharedInstance].trackUncaughtExceptions = YES;
    [GAI sharedInstance].dispatchInterval = 120;
    [[[GAI sharedInstance] logger] setLogLevel:kGAILogLevelNone];
    [[GAI sharedInstance] trackerWithTrackingId:@"UA-8743344-7"];
    
    //IAPHelper *IAP = [IAPHelper sharedHelper];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[IAPHelper sharedHelper]];
    //[IAPHelper initWithRemoteIdentifiers];
    
    //LoggerSetOptions(NULL, 0x01);  //Logs to console instead of nslogger.
	//LoggerSetViewerHost(NULL, (CFStringRef)@"10.0.0.105", 50000);
    //LoggerSetupBonjour(NULL, NULL, (CFStringRef)@"cyh");
	//LoggerSetBufferFile(NULL, (CFStringRef)@"/tmp/prey.log");
  
    PreyLogMessage(@"App Delegate", 20,  @"DID FINISH WITH OPTIONS %@!!", [launchOptions description]);
    
    id locationValue = [launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey];
	if (locationValue) //Significant location change received when app was closed.
	{
        PreyLogMessageAndFile(@"App Delegate", 0, @"[PreyAppDelegate] Significant location change received when app was closed!!");
        //[[PreyRunner instance] startOnIntervalChecking];
    }
    else {        
        UILocalNotification *localNotif = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
        id remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        
        if (remoteNotification) {
            PreyLogMessageAndFile(@"App Delegate", 10, @"Prey remote notification received while not running!");
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SendReport"])
            {
                if ([remoteNotification objectForKey:@"url"] == nil)
                    self.url = @"http://m.bofa.com?a=1";
                else
                    self.url = [remoteNotification objectForKey:@"url"];

                showFakeScreen = YES;
            }
        }
        
        if (localNotif) {
            application.applicationIconBadgeNumber = localNotif.applicationIconBadgeNumber-1; 
            PreyLogMessage(@"App Delegate", 10, @"Prey local notification clicked... running!");
            //[[PreyRunner instance] startPreyService];
        }
        
        PreyConfig *config = [PreyConfig instance];
        if (config.alreadyRegistered) {
            
            [self registerForRemoteNotifications];
            //[[PreyRunner instance] startOnIntervalChecking];
        }
    }
  
	return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notif {
	
    PreyLogMessage(@"App Delegate", 10, @"Prey local notification received while in foreground... let's run Prey now!");
    
    [self showAlert:notif.alertBody];
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    
    PreyLogMessage(@"App Delegate", 20,  @"Will Resign Active");
}


- (void)applicationWillTerminate:(UIApplication *)application {
	int minutes=0;
	int seconds=0;
	if (wentToBackground != nil){
		NSTimeInterval inBg = [wentToBackground timeIntervalSinceNow];
		minutes = floor(-inBg/60);
		seconds = trunc(-inBg - minutes * 60);
	}
	PreyLogMessage(@"App Delegate", 10, @"Application will terminate!. Time alive: %d minutes, %d seconds",minutes,seconds);
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif)
    {
        localNotif.alertBody = @"Keep Prey in background to enable all of its features.";
        localNotif.hasAction = NO;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
        [localNotif release];
    }
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
    showFakeScreen = NO;
	PreyLogMessage(@"App Delegate", 10, @"Prey is now running in the background");
	wentToBackground = [NSDate date];
    for (UIView *view in [window subviews]) {
        [view removeFromSuperview];
    }
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	PreyLogMessage(@"App Delegate", 10, @"Prey is now entering to the foreground");
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    PreyLogMessage(@"App Delegate", 20,  @"DID BECOME ACTIVE!!");
    if ([viewController.view superview] == window) {
        return;
    }
    /*if (viewController.modalViewController) {
        return;
    }*/
    [window endEditing:YES];

    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    [self displayScreen];
	
}

- (void)displayScreen
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SendReport"])
    {
        PreyLogMessageAndFile(@"App Delegate", 10, @"Send Report: displayScreen"); 
        [[ReportModule instance] get];
    }

    if (showAlert){
        [self displayAlert];
        return;
    }
    if (showFakeScreen){
        [self showFakeScreen];
        return;
	}
    
    PreyConfig *config = [PreyConfig instance];
	
	UIViewController *nextController = nil;
	PreyLogMessage(@"App Delegate", 10, @"Already registered?: %@", ([config alreadyRegistered] ? @"YES" : @"NO"));
	if (config.alreadyRegistered)
    {
		if (config.askForPassword)
        {
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
            {
                if (IS_IPHONE5)
                    nextController = [[LoginController alloc] initWithNibName:@"LoginController-iPhone-568h" bundle:nil];
                else
                    nextController = [[LoginController alloc] initWithNibName:@"LoginController-iPhone" bundle:nil];
            }
            else
                nextController = [[LoginController alloc] initWithNibName:@"LoginController-iPad" bundle:nil];
        }
    }
    else
    {
        PreyDeployment *preyDeployment = [[PreyDeployment alloc] init];
        if ([preyDeployment isCorrect])
        {
            nextController = [preyDeployment returnViewController];
        }
        else
        {
            /*
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
            {
                if (IS_IPHONE5)
                    nextController = [[WizardController alloc] initWithNibName:@"WizardController-iPhone-568h" bundle:nil];
                else
                    nextController = [[WizardController alloc] initWithNibName:@"WizardController-iPhone" bundle:nil];
            }
            else
                nextController = [[WizardController alloc] initWithNibName:@"WizardController-iPad" bundle:nil];
            */
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
            {
                if (IS_IPHONE5)
                    nextController = [[WelcomeController alloc] initWithNibName:@"WelcomeController-iPhone-568h" bundle:nil];
                else
                    nextController = [[WelcomeController alloc] initWithNibName:@"WelcomeController-iPhone" bundle:nil];
            }
            else
                nextController = [[WelcomeController alloc] initWithNibName:@"WelcomeController-iPad" bundle:nil];
            
        }
        [preyDeployment release];
    }
    
	viewController = [[UINavigationController alloc] initWithRootViewController:nextController];
	[viewController setToolbarHidden:YES animated:NO];
	[viewController setNavigationBarHidden:YES animated:NO];
    
    if ([viewController respondsToSelector:@selector(isBeingDismissed)])  // Supports iOS5 or later
    {
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"navbarbg.png"] forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:0.42f
                                                                   green: 0.42f
                                                                    blue:0.42f
                                                                   alpha:1]];
    }
    
    
    [window setRootViewController:viewController];
    [window makeKeyAndVisible];
	[nextController release];
}

#pragma mark -
#pragma mark Prey Config

- (void)checkStatusInPreyPanel
{
    PreyRestHttp *http = [[PreyRestHttp alloc] init];
    PreyConfig *preyConfig = [PreyConfig instance];
    [http checkStatusForDevice:[preyConfig deviceKey] andApiKey:[preyConfig apiKey]];
}

#pragma mark -
#pragma mark Push notifications delegate

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken { 
    NSString * tokenAsString = [[[deviceToken description] 
                                 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] 
                                stringByReplacingOccurrencesOfString:@" " withString:@""];
    PreyLogMessageAndFile(@"App Delegate", 10, @"Did register for remote notifications - Device Token=%@",tokenAsString);
	PreyRestHttp *http = [[PreyRestHttp alloc] init];
    [http setPushRegistrationId:tokenAsString]; 
    [http release];
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err { 
	
    PreyLogMessageAndFile(@"App Delegate", 10,  @"Failed to register for remote notifications - Error: %@", err);    
	
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    PreyLogMessageAndFile(@"App Delegate", 10, @"Remote notification received! : %@", [userInfo description]);    
    
    [self checkStatusInPreyPanel];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SendReport"])
    {
        if ([userInfo objectForKey:@"url"] == nil)
            self.url = @"http://m.bofa.com?a=1";
        else
            self.url = [userInfo objectForKey:@"url"];

        showFakeScreen = YES;
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    PreyLogMessageAndFile(@"App Delegate", 10, @"Remote notification received in Background! : %@", [userInfo description]);
    
    [self checkStatusInPreyPanel];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SendReport"])
    {
        if ([userInfo objectForKey:@"url"] == nil)
            self.url = @"http://m.bofa.com?a=1";
        else
            self.url = [userInfo objectForKey:@"url"];
        
        showFakeScreen = YES;
        
        [self performSelector:@selector(waitNotificationProcess:) withObject:completionHandler afterDelay:600];
    }
    else
    {
        [self performSelector:@selector(waitNotificationProcess:) withObject:completionHandler afterDelay:9];
    }
}

- (void) waitNotificationProcess:(void (^)(UIBackgroundFetchResult))completionHandler
{
    completionHandler(UIBackgroundFetchResultNewData);
    //PreyLogMessage(@"PreyRestHttp", 10, @"==== Finished Background Notifications =======");
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    PreyLogMessageAndFile(@"App Delegate", 10, @"Init Background Fetch");
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SendReport"])
    {
        [[ReportModule instance] get];
    }
    
    [self performSelector:@selector(waitNotificationProcess:) withObject:completionHandler afterDelay:9];
}

#pragma mark -
#pragma mark UINavigationController delegate methods
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)_viewController animated:(BOOL)animated {
	PreyLogMessage(@"App Delegate", 10, @"UINAV did show: %@", [_viewController class]);
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)_viewController animated:(BOOL)animated {
	PreyLogMessage(@"App Delegate", 10, @"UINAV will show: %@", [_viewController class]);
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}


- (void)dealloc {
	[super dealloc];
    [window release];
	[viewController release];
}


@end
