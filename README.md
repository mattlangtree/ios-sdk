# Doorbell iOS SDK

The Doorbell iOS SDK.

## Full documentation

You can view the full documentation here: https://doorbell.io/docs/ios

## Requirements

Doorbell needs the ```QuartzCore.framework``` to be included in your project.

You'll need [Automatic Reference Counting (ARC)](http://en.wikipedia.org/wiki/Automatic_Reference_Counting) enabled.

## Usage

In the ViewController where you want to use Doorbell, you'll need to import the library using:

```objc
#import "Doorbell.h"
```

Then when you want to show the dialog:

```objc
NSString *appId = @"123";
NSString *appKey = @"xxxxxxxxxxxxxxxxxx";

Doorbell *feedback = [Doorbell doorbellWithApiKey:appKey appId:appId];
[feedback showFeedbackDialogInViewController:self completion:^(NSError *error, BOOL isCancelled) {
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
}];
```

To pre-populate the email address (if the user is logged in for example):

```objc
NSString *appId = @"123";
NSString *appKey = @"xxxxxxxxxxxxxxxxxx";

Doorbell *feedback = [Doorbell doorbellWithApiKey:appKey appId:appId];
feedback.showEmail = NO;
feedback.email = @"email@example.com";
[feedback showFeedbackDialogInViewController:self completion:^(NSError *error, BOOL isCancelled) {
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
}];
```
