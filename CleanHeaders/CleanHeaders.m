//
//  CleanHeaders.m
//  CleanHeaders
//
//  Created by Karthik on 07/10/2015.
//  Copyright © 2015 Karthikeya Udupa K M. All rights reserved.
//

#import "TRVSXcode.h"
#import "CleanHeaders.h"

@interface CleanHeaders ()

@property(nonatomic, strong, readwrite) NSBundle *bundle;
@end

@implementation CleanHeaders

+ (instancetype)sharedPlugin {
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(didApplicationFinishLaunchingNotification:)
         name:NSApplicationDidFinishLaunchingNotification
         object:nil];
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification *)noti {
    // removeObserver
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSApplicationDidFinishLaunchingNotification
     object:nil];
    
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *actionMenuItem =
        [[NSMenuItem alloc] initWithTitle:@"Clean Header Imports"
                                   action:@selector(cleanHeaderAction)
                            keyEquivalent:@"|"];
        [menuItem setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
        [actionMenuItem setTarget:self];
        [[menuItem submenu] addItem:actionMenuItem];
    }
}

/**
 *  Actual action to clean the header.
 */
- (void)cleanHeaderAction {
    if (![TRVSXcode textViewHasSelection]) {
        [self formatRanges:@[
                             [NSValue valueWithRange:[TRVSXcode wholeRangeOfTextView]]
                             ] inDocument:[TRVSXcode sourceCodeDocument]];
    } else {
        [self formatRanges:[[TRVSXcode textView] selectedRanges]
                inDocument:[TRVSXcode sourceCodeDocument]];
    }
}

- (NSString *)formatSelection:(NSString *)content {
    // Let's assume all header files start with an #import, #include, @import,
    // import.
    NSString *traditionalImportPrefix = @"#import \"";
    NSString *traditionalFrameworkImportPrefix = @"#import <";
    NSString *frameworkImportPrefix = @"@import";
    NSString *traditionalIncludePrefix = @"#include";
    NSString *swiftPrefix = @"import";
    
    // Convert the entire source into an array based on new lines.
    // Hence the imports have to be alteast in new line to work.
    NSMutableArray *lines = [[NSMutableArray alloc]
                             initWithArray:[content componentsSeparatedByString:@"\n"]];
    
    // Position of the first and last line of header, to be used for repalcement
    // of header content.
    NSInteger __block initalIndex = -1;
    NSInteger __block lastIndex = -1;
    BOOL __block endOfFileWithNewLine = YES;  // Indicates if the selection's last
                                              // line was a new line.
    NSMutableArray *headerRows = [[NSMutableArray alloc] init];
    
    // Go through each of the line and identify any header elements.
    [lines enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx,
                                        BOOL *_Nonnull stop) {
        NSString *cleansedLine =
        [string stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        BOOL isLineHeader = [cleansedLine hasPrefix:traditionalImportPrefix] ||
        [cleansedLine hasPrefix:traditionalIncludePrefix] ||
        [cleansedLine hasPrefix:frameworkImportPrefix] ||
        [cleansedLine hasPrefix:swiftPrefix] ||
        [cleansedLine hasPrefix:traditionalFrameworkImportPrefix]  ;
        
        // If the line is a header and no header element has been detected so far,
        // mark this as the start of the header segment.
        if (isLineHeader && initalIndex < 0) {
            initalIndex = idx;
        } else if (initalIndex >= 0 && !(isLineHeader || ![cleansedLine length])) {
            // If the inital index has been set AND the line is not a header or a new
            // line, then this is to be marked as the end of header segment and
            // enumeration has to be stopped.
            lastIndex = idx;
            *stop = YES;
        }
        
        if (initalIndex >= 0 && lastIndex < 0) {
            // If the inital index is already set and we are in this condition it
            // means we are parsing the header. Check for duplicates and ensure that
            // it is not a new line and then add to the header rows array.
            if (![headerRows containsObject:cleansedLine] && [cleansedLine length]) {
                [headerRows addObject:cleansedLine];
            }
        }
        
        // Reached the end of the selection or a file. (In case of a selection or a
        // header only file)
        if (idx >= lines.count - 1) {
            lastIndex = idx + 1;
            
            // If the end was a header and not a new line and also marked the end of
            // selection, a new line would look odd.
            if ([cleansedLine length]) {
                endOfFileWithNewLine = NO;
            }
        }
        
    }];
    
    // If both the indices are set it means that we have a header section in the
    // file and it needs replacing after sorting.
    if (lastIndex >= 0 && initalIndex >= 0)
    {
        
        NSMutableArray *traditionalImportPrefixRows = [[headerRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", traditionalImportPrefix]] mutableCopy];
        
        NSMutableArray *traditionalFrameworkImportPrefixRows = [[headerRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", traditionalFrameworkImportPrefix]] mutableCopy];
        
        NSMutableArray *frameworkImportPrefixRows = [[headerRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", frameworkImportPrefix]]mutableCopy];
        
        
        NSMutableArray *traditionalIncludePrefixRows = [[headerRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", traditionalIncludePrefix]]mutableCopy];
        
        
        NSMutableArray *swiftPrefixRows = [[headerRows filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", swiftPrefix]]mutableCopy];
        

        [traditionalImportPrefixRows sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [traditionalFrameworkImportPrefixRows sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [frameworkImportPrefixRows sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [traditionalIncludePrefixRows sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        [swiftPrefixRows sortUsingSelector:@selector(caseInsensitiveCompare:)];
        
        
        if (traditionalImportPrefixRows.count > 0)
        {
            [traditionalImportPrefixRows addObject:@"\n"];
        }
        
        if (traditionalFrameworkImportPrefixRows.count > 0)
        {
            [traditionalFrameworkImportPrefixRows addObject:@"\n"];
        }
        
        if (frameworkImportPrefixRows.count > 0)
        {
            [frameworkImportPrefixRows addObject:@"\n"];
        }
        
        if (traditionalIncludePrefixRows.count > 0)
        {
            [traditionalIncludePrefixRows addObject:@"\n"];
        }
        
        if (swiftPrefixRows.count > 0)
        {
            [swiftPrefixRows addObject:@"\n"];
        }
        
        
        [headerRows removeAllObjects];
        [headerRows addObjectsFromArray:frameworkImportPrefixRows];
        [headerRows addObjectsFromArray:traditionalFrameworkImportPrefixRows];
        [headerRows addObjectsFromArray:traditionalImportPrefixRows];
        [headerRows addObjectsFromArray:traditionalIncludePrefixRows];
        [headerRows addObjectsFromArray:swiftPrefixRows];
        
        
        NSString *headerName = [[[TRVSXcode sourceCodeDocument].displayName stringByDeletingPathExtension] stringByAppendingPathExtension:@"h"];
        
        NSString *correspondingHeaderImport = [NSString stringWithFormat:@"#import \"%@\"", headerName];
        
        BOOL foundCorrespondingHeaderImport = NO;
        NSUInteger indexOfCorrespondingHeaderImport = 0;
        
        for (NSString *import in headerRows)
        {
            if ([import isEqualToString:correspondingHeaderImport])
            {
                foundCorrespondingHeaderImport = YES;
                indexOfCorrespondingHeaderImport = [headerRows indexOfObject:import];
                break;
            }
        }
        
        if (foundCorrespondingHeaderImport)
        {
            [headerRows removeObjectAtIndex:indexOfCorrespondingHeaderImport];
            [headerRows insertObject:correspondingHeaderImport atIndex:0];
            [headerRows insertObject:@"\n" atIndex:1];
        }
//        
//        if ([[headerRows lastObject] isEqualToString:@"\n"])
//        {
//            [headerRows removeLastObject];
//        }
        // Add a new line to make it look clean (if needed)
//        if (endOfFileWithNewLine) {
//            [headerRows addObject:@"\r"];
//        }
        // replace it in the array of all lines.
        [lines replaceObjectsInRange:NSMakeRange(initalIndex,
                                                 (lastIndex - initalIndex))
                withObjectsFromArray:headerRows];
    }
    
    return [lines componentsJoinedByString:@"\r"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)formatRanges:(NSArray *)ranges
          inDocument:(IDESourceCodeDocument *)document {
    if (![self shouldFormat:document]) return;
    
    DVTSourceTextStorage *textStorage = [document textStorage];
    
    NSRange range = [ranges.firstObject rangeValue];
    NSString *formattedString =
    [self formatSelection:[[textStorage string] substringWithRange:range]];
    [textStorage replaceCharactersInRange:range
                               withString:formattedString
                          withUndoManager:document.undoManager];
}

- (BOOL)shouldFormat:(IDESourceCodeDocument *)document {
    return [[NSSet setWithObjects:@"c", @"h", @"cpp", @"cc", @"cxx", @"hh",
             @"hpp", @"ipp", @"m", @"mm", @"swift", nil]
            containsObject:[[[document fileURL] pathExtension] lowercaseString]];
}

@end
