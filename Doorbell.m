#import "Doorbell.h"
#import "DoorbellDialog.h"

NSString * const EndpointTemplate = @"https://doorbell.io/api/applications/%@/%@?key=%@";
NSString * const UserAgent = @"Doorbell iOS SDK";

@interface Doorbell () <DoorbellDialogDelegate>

@property (copy, nonatomic)     DoorbellCompletionBlock block;//Block to give the result
@property (strong, nonatomic)   DoorbellDialog *dialog;

@end

@implementation Doorbell

- (id)initWithApiKey:(NSString *)apiKey appId:(NSString *)appID
{
    self = [super init];
    if (self) {
        _showEmail = YES;
        _showPoweredBy = YES;
        self.apiKey = apiKey;
        self.appID = appID;
    }
    return self;
}

+ (Doorbell*)doorbellWithApiKey:(NSString *)apiKey appId:(NSString *)appID
{
    return [[[self class] alloc] initWithApiKey:apiKey appId:appID];
}

- (BOOL)checkCredentials
{
    if (self.appID.length == 0 || self.apiKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"doorbell.io" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Doorbell. Credentials could not be founded (key, appID)."}];
        self.block(error, YES);
        return NO;
    }

    return YES;
}

- (void)showFeedbackDialogInViewController:(UIViewController *)vc completion:(DoorbellCompletionBlock)completion
{
    if (![self checkCredentials]) {
        return;
    }

    if (!vc || ![vc isKindOfClass:[UIViewController class]]) {
        NSError *error = [NSError errorWithDomain:@"doorbell.io" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Doorbell needs a ViewController"}];
        completion(error, YES);
        return;
    }

    self.block = completion;
    self.dialog = [[DoorbellDialog alloc] initWithViewController:vc];
    self.dialog.delegate = self;
    self.dialog.showEmail = self.showEmail;
    self.dialog.email = self.email;
    self.dialog.showPoweredBy = self.showPoweredBy;
    [vc.view addSubview:self.dialog];

    //Open - Request sent when the form is displayed to the user.
    [self sendOpen];
}

- (void)showFeedbackDialogWithCompletionBlock:(DoorbellCompletionBlock)completion
{
    self.block = completion;
    UIWindow *currentWindow = [UIApplication sharedApplication].keyWindow;
    self.dialog = [[DoorbellDialog alloc] initWithFrame:currentWindow.frame];
    self.dialog.delegate = self;
    self.dialog.showEmail = self.showEmail;
    self.dialog.email = self.email;
    self.dialog.showPoweredBy = self.showPoweredBy;
    [currentWindow addSubview:self.dialog];
}

#pragma mark - Selectors

- (void)fieldError:(NSString*)validationError
{
    if ([validationError hasPrefix:@"Your email address is required"]) {
        [self.dialog highlightEmailEmpty];
    }
    else if ([validationError hasPrefix:@"Invalid email address"]) {
        [self.dialog highlightEmailInvalid];
    }
    else {
        [self.dialog highlightMessageEmpty];
    }

    self.dialog.sending = NO;
}

- (void)finish
{
    [self.dialog removeFromSuperview];
    self.block(nil, NO);
}

#pragma mark - Dialog delegate

- (void)dialogDidCancel:(DoorbellDialog*)dialog
{
    [dialog removeFromSuperview];
    self.block(nil, YES);
}

- (void)dialogDidSend:(DoorbellDialog*)dialog
{
    self.dialog.sending = YES;
    [self sendSubmit:dialog.bodyText email:dialog.email];
//    [dialog removeFromSuperview];
//    self.block(nil, YES);
}

#pragma mark - Endpoints

- (void)sendOpen
{
    if (![self checkCredentials]) {
        return;
    }

    NSString *query = [NSString stringWithFormat:EndpointTemplate, self.appID, @"open", self.apiKey];
    NSURL *openURL = [NSURL URLWithString:query];
    NSMutableURLRequest *openRequest = [NSMutableURLRequest requestWithURL:openURL];
    [openRequest setHTTPMethod:@"POST"];
    [openRequest addValue:UserAgent forHTTPHeaderField:@"User-Agent"];
    [NSURLConnection sendAsynchronousRequest:openRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {

                               if ([r isKindOfClass:[NSHTTPURLResponse class]]) {
                                   NSHTTPURLResponse *httpResp = (id)r;
                                   if (httpResp.statusCode != 201) {
                                       NSLog(@"%d: There was an error trying to connect with doorbell. Open called failed", httpResp.statusCode);
                                       NSLog(@"%@", [NSString stringWithUTF8String:d.bytes]);
                                   }
                               }
                           }];
}

- (void)sendSubmit:(NSString*)message email:(NSString*)email
{
    NSString *query = [NSString stringWithFormat:EndpointTemplate, self.appID, @"submit", self.apiKey];
    NSURL *submitURL = [NSURL URLWithString:query];

    NSString *escapedEmail = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                  NULL,
                                                                                  (CFStringRef)email,
                                                                                  NULL,
                                                                                  CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                  kCFStringEncodingUTF8));


    NSString *escapedMessage = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                                   NULL,
                                                                                                   (CFStringRef)message,
                                                                                                   NULL,
                                                                                                   CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                                   kCFStringEncodingUTF8));



    NSMutableURLRequest *submitRequest = [NSMutableURLRequest requestWithURL:submitURL];
    [submitRequest setHTTPMethod:@"POST"];
    [submitRequest addValue:UserAgent forHTTPHeaderField:@"User-Agent"];
    NSString *postString = [NSString stringWithFormat:@"message=%@&email=%@", escapedMessage, escapedEmail];
    [submitRequest setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];

    [NSURLConnection sendAsynchronousRequest:submitRequest
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               if ([r isKindOfClass:[NSHTTPURLResponse class]]) {
                                   NSHTTPURLResponse *httpResp = (id)r;
                                   NSString *content = [NSString stringWithUTF8String:d.bytes];
                                   NSLog(@"%d:%@", httpResp.statusCode, content);

                                   [self manageSubmitResponse:httpResp content:content];
                               }
                           }];

}

- (void)manageSubmitResponse:(NSHTTPURLResponse*)response content:(NSString*)content
{
    switch (response.statusCode) {
        case 201:
            [self finish];
            break;
        case 400:
            [self fieldError:content];
            break;

        default:
            [self.dialog removeFromSuperview];
            self.block([NSError errorWithDomain:@"doorbell.io" code:3 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%d: HTTP unexpected\n%@", response.statusCode, content]}] , YES);
            break;
    }
}
@end
