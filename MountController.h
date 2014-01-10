//
//  MountController.h
//  PreLoginMount
//
//  Created by Iliya Lindov on 12/27/13.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MountController : NSObject{
    IBOutlet NSTextField *statusField;
    IBOutlet NSPopUpButton *usersList;
    IBOutlet NSSecureTextFieldCell *diskUnlockPassword;
    IBOutlet NSProgressIndicator *spinner;
    IBOutlet NSButton *checkIntegrity;
    IBOutlet NSButton *verboseMode;
    IBOutlet NSButton *mountButton;
    IBOutlet NSButton *closeAndContinueButton;
    IBOutlet NSButton *clearVerboseLogArea;
    IBOutlet NSTextView *verboseLogArea;
}

- (IBAction)attemptToMountWithPassword:(id)sender;
- (IBAction)showVerboseLog:(id)sender;
- (IBAction)clearVerboseLog:(id)sender;
- (IBAction)closeApplication:(id)sender;

@end
