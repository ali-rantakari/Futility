//
//  UIAlertView+FKBlocks.m
//  iOS 4.3+
// 
//
// Copyright © Futurice (http://www.futurice.com)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
//
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// * Neither the name of Futurice nor the names of its contributors may be used to
//   endorse or promote products derived from this software without specific prior
//   written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
// OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//

#import "UIAlertView+FKBlocks.h"
#import <objc/runtime.h>

#if !__has_feature(objc_arc)
#warning "This file must be compiled with ARC enabled"
#endif

static void *kFKDismissBlockAssociationKey = (void *)&kFKDismissBlockAssociationKey;
static void *kFKCancelBlockAssociationKey = (void *)&kFKCancelBlockAssociationKey;

@implementation UIAlertView (UIAlertView_FKBlocks)

+ (UIAlertView *) fk_alertViewWithTitle:(NSString*)title
                                message:(NSString*)message
                      cancelButtonTitle:(NSString*)cancelButtonTitle
                      otherButtonTitles:(NSArray*)otherButtonTitles
                         dismissHandler:(FKAlertViewDismissBlock)dismissBlock
                          cancelHandler:(FKAlertViewCancelBlock)cancelBlock
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:[self class]
                                          cancelButtonTitle:cancelButtonTitle
                                          otherButtonTitles:nil];
    
    for (NSString *otherButtonTitle in otherButtonTitles)
        [alert addButtonWithTitle:otherButtonTitle];
    
    objc_setAssociatedObject(alert, kFKDismissBlockAssociationKey, dismissBlock, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(alert, kFKCancelBlockAssociationKey, cancelBlock, OBJC_ASSOCIATION_COPY);
    
    return alert;
}

+ (UIAlertView *) fk_showWithTitle:(NSString*)title
                           message:(NSString*)message
                 cancelButtonTitle:(NSString*)cancelButtonTitle
                 otherButtonTitles:(NSArray*)otherButtonTitles
                    dismissHandler:(FKAlertViewDismissBlock)dismissBlock
                     cancelHandler:(FKAlertViewCancelBlock)cancelBlock
{
    UIAlertView *alert = [UIAlertView fk_alertViewWithTitle:title
                                                    message:message
                                          cancelButtonTitle:cancelButtonTitle
                                          otherButtonTitles:otherButtonTitles
                                             dismissHandler:dismissBlock
                                              cancelHandler:cancelBlock];
    [alert show];
    return alert;
}

#define TAG_INPUT_FIELD 1977

+ (UIAlertView *) fk_showWithTitle:(NSString*)title
                           message:(NSString*)message
                     textFieldText:(NSString*)fieldText
                       placeholder:(NSString*)fieldPlaceholder
                       secureInput:(BOOL)secureInput
                      keyboardType:(UIKeyboardType)keyboardType
                 cancelButtonTitle:(NSString*)cancelButtonTitle
                 otherButtonTitles:(NSArray*)otherButtonTitles
                    dismissHandler:(FKAlertViewDismissBlock)dismissBlock
                     cancelHandler:(FKAlertViewCancelBlock)cancelBlock
{
    UIAlertView *alert = [UIAlertView fk_alertViewWithTitle:title
                                                    message:message
                                          cancelButtonTitle:cancelButtonTitle
                                          otherButtonTitles:otherButtonTitles
                                             dismissHandler:dismissBlock
                                              cancelHandler:cancelBlock];
    
    UITextField *field = nil;
    if ([alert respondsToSelector:@selector(alertViewStyle)])
    {
        // iOS 5+ : Supports text field alerts natively.
        alert.alertViewStyle = secureInput ? UIAlertViewStyleSecureTextInput : UIAlertViewStylePlainTextInput;
        field = [alert textFieldAtIndex:0];
        field.keyboardType = keyboardType;
        field.placeholder = fieldPlaceholder;
        field.text = fieldText;
        [alert show];
    }
    else
    {
        // iOS 4.x or earlier : must implement hacky workaround.
        
        // We add newlines to the end of the 'message' to reserve a bit of space
        // below it, and then drop our UITextField there.
        // 
        // This works fine unless 'message' is so long that the alert view will
        // display it in a scroll view, in which case we won't be able to reserve
        // space for the text field by adding newlines to the end.
        // 
        // Three lines of message text (~100pt height) is shown as a normal label,
        // but four lines (~120pt height) is shown as a scroll view. So we remove one
        // word at a time from our message until it's short enough to fit on three
        // lines:
        // 
        NSString *modifiedMessage = alert.message;
        BOOL messageIsTruncated = NO;
        while (110.0f < [[modifiedMessage stringByAppendingFormat:@"%@\n\n\n", (messageIsTruncated ? @"…" : @"")]
                         sizeWithFont:[UIFont systemFontOfSize:16]
                         constrainedToSize:CGSizeMake(260, 1000)
                         lineBreakMode:UILineBreakModeWordWrap].height)
        {
            messageIsTruncated = YES;
            NSArray *words = [modifiedMessage componentsSeparatedByString:@" "];
            modifiedMessage = [[words subarrayWithRange:NSMakeRange(0, words.count-1)] componentsJoinedByString:@" "];
        }
        
        alert.message = [modifiedMessage stringByAppendingFormat:@"%@\n\n\n", (messageIsTruncated ? @"…" : @"")];
        
        field = [[UITextField alloc] initWithFrame:CGRectMake(16, 0, 252, 25)];
        field.font = [UIFont systemFontOfSize:18];
        field.keyboardAppearance = UIKeyboardAppearanceAlert;
        field.secureTextEntry = secureInput;
        field.borderStyle = UITextBorderStyleRoundedRect;
        field.tag = TAG_INPUT_FIELD;
        field.keyboardType = keyboardType;
        field.placeholder = fieldPlaceholder;
        field.text = fieldText;
        [field becomeFirstResponder];
        [alert addSubview:field];
        
        [alert show];
        
        // The alert view positions its subviews only after calling -show, so
        // we have to do this here:
        CGFloat alertLabelsBottom = 0;
        for (UIView *subview in alert.subviews)
        {
            if (![subview isKindOfClass:[UILabel class]])
                continue;
            CGFloat bottom = CGRectGetMaxY(subview.frame);
            if (alertLabelsBottom < bottom)
                alertLabelsBottom = bottom;
        }
        field.frame = CGRectMake(field.frame.origin.x,
                                 alertLabelsBottom - field.frame.size.height,
                                 field.frame.size.width,
                                 field.frame.size.height);
    }
    
    return alert;
}

+ (UIAlertView*) fk_showWithTitle:(NSString*)title
                          message:(NSString*)message
                        okHandler:(FKAlertViewCancelBlock)okBlock
{
    return [self fk_showWithTitle:title
                          message:message
                cancelButtonTitle:NSLocalizedString(@"Ok", @"Alert view dialog Ok button")
                otherButtonTitles:nil
                   dismissHandler:NULL
                    cancelHandler:okBlock];
}

+ (UIAlertView*) fk_showCancelableWithTitle:(NSString*)title
                                    message:(NSString*)message
                                 actionName:(NSString*)actionName
                              actionHandler:(FKAlertViewDismissBlock)actionBlock
{
    return [self fk_showWithTitle:title
                          message:message
                cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert view dialog cancel button")
                otherButtonTitles:@[actionName]
                   dismissHandler:actionBlock
                    cancelHandler:NULL];
}

+ (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    FKAlertViewDismissBlock dismissBlock = objc_getAssociatedObject(alertView, kFKDismissBlockAssociationKey);
    FKAlertViewCancelBlock cancelBlock = objc_getAssociatedObject(alertView, kFKCancelBlockAssociationKey);
    
    if (buttonIndex == [alertView cancelButtonIndex])
    {
        if (cancelBlock != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                cancelBlock(alertView);
            });
        }
    }
    else
    {
        UITextField *inputField;
        if ([self respondsToSelector:@selector(alertViewStyle)])
            inputField = [alertView textFieldAtIndex:0];
        else
            inputField = (UITextField *)[alertView viewWithTag:TAG_INPUT_FIELD];
        NSString *input = inputField.text;
        
        if (dismissBlock != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                dismissBlock(alertView, buttonIndex, input);
            });
        }
    }
    
    objc_setAssociatedObject(alertView, kFKDismissBlockAssociationKey, nil, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(alertView, kFKCancelBlockAssociationKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

@end