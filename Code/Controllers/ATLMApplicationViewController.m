//
//  ATLMApplicationViewController.m
//  Atlas Messenger
//
//  Created by Klemen Verdnik on 6/26/16.
//  Copyright © 2016 Layer, Inc. All rights reserved.
//

#import "ATLMApplicationViewController.h"
#import "ATLMSplashView.h"
#import "ATLMQRScannerController.h"
#import "ATLMRegistrationViewController.h"
#import "ATLMConversationListViewController.h"
#import "ATLMConversationViewController.h"
#import "ATLMUtilities.h"
#import "ATLMSplitViewController.h"
#import "ATLMNavigationController.h"

///-------------------------
/// @name Application States
///-------------------------

typedef NS_ENUM(NSUInteger, ATLMApplicationState) {
    /**
     @abstract A state where the app has not yet established a state.
     */
    ATLMApplicationStateIndeterminate           = 0,
    
    /**
     @abstract A state where the app doesn't have a Layer appID yet.
     */
    ATLMApplicationStateAppIDNotSet             = 1,
    
    /**
     @abstract A state where the app has the appID, but no user credentials.
     */
    ATLMApplicationStateCredentialsRequired     = 2,
    
    /**
     @abstract A state where the app is fully authenticated.
     */
    ATLMApplicationStateAuthenticated           = 3
};

static NSString *const ATLMPushNotificationSoundName = @"layerbell.caf";
static void *ATLMApplicationViewControllerObservationContext = &ATLMApplicationViewControllerObservationContext;

@interface ATLMApplicationViewController () <ATLMQRScannerControllerDelegate, ATLMRegistrationViewControllerDelegate, ATLMConversationListViewControllerPresentationDelegate>

@property (assign, nonatomic, readwrite) ATLMApplicationState state;
@property (nullable, nonatomic) ATLMSplashView *splashView;
@property (nullable, nonatomic) ATLMQRScannerController *QRCodeScannerController;
@property (nullable, nonatomic) UINavigationController *registrationNavigationController;
@property (nullable, nonatomic) ATLMSplitViewController *splitViewController;
@property (nullable, nonatomic) ATLMConversationListViewController *conversationListViewController;

@end

@implementation ATLMApplicationViewController

- (nonnull id)init
{
    self = [super init];
    if (self) {
        _state = ATLMApplicationStateIndeterminate;
        [self addObserver:self forKeyPath:@"state" options:0 context:ATLMApplicationViewControllerObservationContext];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ATLMApplicationState)determineInitialApplicationState
{
    if (self.layerController == nil) {
        return ATLMApplicationStateAppIDNotSet;
    } else {
        if (self.layerController.layerClient.authenticatedUser == nil) {
            return ATLMApplicationStateCredentialsRequired;
        } else {
            return ATLMApplicationStateAuthenticated;
        }
    }
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString*, id> *)change context:(nullable void *)context
{
    if (context == ATLMApplicationViewControllerObservationContext) {
        if ([keyPath isEqualToString:@"state"]) {
            [self presentViewControllerForApplicationState:self.state];
        }
    }
}

#pragma mark - UIViewController Overrides

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self makeSplashViewVisible:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.state = [self determineInitialApplicationState];
}

#pragma mark - Splash View

- (void)makeSplashViewVisible:(BOOL)visible
{
    if (visible) {
        // Add ATLMSplashView to the self.view
        if (!self.splashView) {
            self.splashView = [[ATLMSplashView alloc] initWithFrame:self.view.bounds];
        }
        [self.view addSubview:self.splashView];
    } else {
        // Fade out self.splashView and remove it from the self.view subviews' stack.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.5 animations:^{
                self.splashView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self.splashView removeFromSuperview];
                self.splashView = nil;
            }];
        });
    }
}

#pragma mark - UI view controller presenting

- (void)presentRegistrationNavigationController
{
    if (!self.registrationNavigationController) {
        self.registrationNavigationController = [[UINavigationController alloc] init];
        self.registrationNavigationController.navigationBarHidden = YES;
        if (!self.childViewControllers.count) {
            // Only if there's no child view controller being presented on top.
            [self presentViewController:self.registrationNavigationController animated:YES completion:nil];
        }
        [self.splitViewController removeFromParentViewController];
        [self.splitViewController.view removeFromSuperview];
        self.splitViewController = nil;
        self.conversationListViewController = nil;
    }
}

- (void)presentQRCodeScannerViewController
{
    if (!self.registrationNavigationController) {
        [self presentRegistrationNavigationController];
    }
    ATLMQRScannerController *QRCodeScannerController = [ATLMQRScannerController new];
    QRCodeScannerController.delegate = self;
    [self.registrationNavigationController pushViewController:QRCodeScannerController animated:NO];
}

- (void)presentRegistrationViewController
{
    if (!self.registrationNavigationController) {
        [self presentRegistrationNavigationController];
    }
    ATLMRegistrationViewController *registrationViewController = [ATLMRegistrationViewController new];
    registrationViewController.delegate = self;
    [self.registrationNavigationController pushViewController:registrationViewController animated:YES];
}

- (void)presentConversationListViewController
{
    [self.registrationNavigationController dismissViewControllerAnimated:YES completion:nil];
    self.registrationNavigationController = nil;
    
    // Add splitview controller onto the current view.
    self.splitViewController = [[ATLMSplitViewController alloc] init];
    [self addChildViewController:_splitViewController];
    [self.view addSubview:_splitViewController.view];
    [self.splitViewController didMoveToParentViewController:self];
    
    // And have the conversation view controller be the detail view controller.
    ATLMConversationViewController *conversationViewController = [ATLMConversationViewController conversationViewControllerWithLayerClient:self.layerController.layerClient];
    [self.splitViewController setDetailViewController:conversationViewController];
    
    // Put the conversation list view controller as the main view controller
    // in the split view.
    self.conversationListViewController = [ATLMConversationListViewController conversationListViewControllerWithLayerClient:self.layerController.layerClient splitViewController:self.splitViewController];
    self.conversationListViewController.presentationDelegate = self;
    [self.splitViewController setMainViewController:self.conversationListViewController];
}

#pragma mark - Managing UI view transitions

- (void)presentViewControllerForApplicationState:(ATLMApplicationState)applicationState
{
    [self makeSplashViewVisible:YES];
    switch (applicationState) {
        case ATLMApplicationStateAppIDNotSet:{
            [self presentQRCodeScannerViewController];
            break;
        }
        case ATLMApplicationStateCredentialsRequired: {
            [self presentRegistrationViewController];
            break;
        }
        case ATLMApplicationStateAuthenticated: {
            [self presentConversationListViewController];
            break;
        }
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Unhandled ATLMApplicationState value=%lu", (NSUInteger)applicationState];
            break;
    }
}

#pragma mark - ATLMQRScannerControllerDelegate implementation

- (void)scannerController:(ATLMQRScannerController *)scannerController didScanLayerAppID:(NSURL *)appID
{
    NSLog(@"Received an appID=%@ from the scannerController=%@", appID, scannerController);
    [self.delegate applicationController:self didCollectLayerAppID:appID];
}

- (void)scannerController:(ATLMQRScannerController *)scannerController didFailWithError:(NSError *)error
{
    ATLMAlertWithError(error);
}

#pragma mark - ATLMRegistrationViewControllerDelegate implementation

- (void)registrationViewController:(ATLMRegistrationViewController *)registrationViewController didSubmitCredentials:(NSDictionary *)credentials
{
    [self.layerController authenticateWithCredentials:credentials completion:^(LYRSession *_Nonnull session, NSError *_Nullable error) {
        if (session) {
            self.state = ATLMApplicationStateAuthenticated;
        } else {
            NSLog(@"Failed to authenticate with credentials=%@. errors=%@", credentials, error);
            ATLMAlertWithError(error);
        }
    }];
}

#pragma mark - ATLMConversationListViewControllerPresentationDelegate implementation

- (void)conversationListViewControllerWillBeDismissed:(nonnull ATLConversationListViewController *)conversationListViewController
{
    // Prepare the current view controller for dismissal of the
    [self makeSplashViewVisible:YES];
    [self.splitViewController setDetailViewController:nil];
}

- (void)conversationListViewControllerWasDismissed:(nonnull ATLConversationListViewController *)conversationListViewController
{
    [self presentViewController:self.registrationNavigationController animated:YES completion:nil];
}

#pragma mark - ATLMLayerControllerDelegate implementation

- (void)applicationController:(ATLMLayerController *)applicationController didChangeState:(ATLMApplicationState)applicationState
{
    // Handle UI transitions
    [self presentViewControllerForApplicationState:applicationState];
}

- (void)applicationController:(ATLMLayerController *)applicationController didFinishHandlingRemoteNotificationForConversation:(LYRConversation *)conversation message:(LYRMessage *)message responseText:(nullable NSString *)responseText
{
    if (responseText.length) {
        // Handle the inline message reply.
        if (!conversation) {
            NSLog(@"Failed to complete inline reply: unable to find Conversation referenced by remote notification.");
            return;
        }
        LYRMessagePart *messagePart = [LYRMessagePart messagePartWithText:responseText];
        NSString *fullName = self.layerController.layerClient.authenticatedUser.displayName;
        NSString *pushText = [NSString stringWithFormat:@"%@: %@", fullName, responseText];
        LYRMessage *message = ATLMessageForParts(self.layerController.layerClient, @[ messagePart ], pushText, ATLMPushNotificationSoundName);
        if (message) {
            NSError *error = nil;
            BOOL success = [conversation sendMessage:message error:&error];
            if (!success) {
                NSLog(@"Failed to send inline reply: %@", [error localizedDescription]);
            }
        }
        return;
    }
    
    // Navigate to the conversation, after the remote notification's been handled.
    BOOL userTappedRemoteNotification = [UIApplication sharedApplication].applicationState == UIApplicationStateInactive;
    if (userTappedRemoteNotification && conversation) {
        [self.conversationListViewController selectConversation:conversation];
    } else if (userTappedRemoteNotification) {
        [SVProgressHUD showWithStatus:@"Loading Conversation"];
    }
}

- (void)setLayerController:(ATLMLayerController *)layerController
{
    if (_layerController == layerController) {
        return;
    }
    
    _layerController = layerController;
    if (layerController) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientWillAttemptToConnectNotification:) name:LYRClientWillAttemptToConnectNotification object:layerController.layerClient];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientDidConnectNotification:) name:LYRClientDidConnectNotification object:layerController.layerClient];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientDidDisconnectNotification:) name:LYRClientDidDisconnectNotification object:layerController.layerClient];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientDidLoseConnectionNotification:) name:LYRClientDidLoseConnectionNotification object:layerController.layerClient];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientDidAuthenticateNotification:) name:LYRClientDidAuthenticateNotification object:layerController.layerClient];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLayerClientDidDeauthenticateNotification:) name:LYRClientDidDeauthenticateNotification object:layerController.layerClient];
        
        // Connect the client
        [layerController.layerClient connectWithCompletion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                NSLog(@"Connected to Layer");
            } else {
                NSLog(@"Failed connection to Layer: %@", error);
            }
        }];
        
        if (self.state != ATLMApplicationStateIndeterminate) {
            self.state = [self determineInitialApplicationState];
        }
    }
}

- (void)handleLayerClientWillAttemptToConnectNotification:(NSNotification *)notification
{
    unsigned long attemptNumber = [notification.userInfo[@"attemptNumber"] unsignedLongValue];
    unsigned long attemptLimit = [notification.userInfo[@"attemptLimit"] unsignedLongValue];
    NSTimeInterval delayInterval = [notification.userInfo[@"delayInterval"] floatValue];
    // Show HUD with message
    if (attemptNumber == 1) {
        [SVProgressHUD showWithStatus:@"Connecting to Layer"];
    } else {
        [SVProgressHUD showWithStatus:[NSString stringWithFormat:@"Connecting to Layer in %lus (%lu of %lu)", (unsigned long)ceil(delayInterval), attemptNumber, attemptLimit]];
    }
}

- (void)handleLayerClientDidConnectNotification:(NSNotification *)notification
{
    // Show HUD with message
    [SVProgressHUD showSuccessWithStatus:@"Connected to Layer"];
}

- (void)handleLayerClientDidDisconnectNotification:(NSNotification *)notification
{
    // Show HUD with message
    [SVProgressHUD showWithStatus:@"Disconnected from Layer"];
}

- (void)handleLayerClientDidLoseConnectionNotification:(NSNotification *)notification
{
    // Show HUD with message
    [SVProgressHUD showErrorWithStatus:@"Lost connection from Layer"];
}

- (void)handleLayerClientDidAuthenticateNotification:(NSNotification *)notification
{
    self.state = ATLMApplicationStateAuthenticated;
}

- (void)handleLayerClientDidDeauthenticateNotification:(NSNotification *)notification
{
    self.state = ATLMApplicationStateCredentialsRequired;
}

@end
