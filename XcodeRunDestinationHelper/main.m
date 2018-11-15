//
//  main.m
//  XcodeRunDestinationHelper
//
//  Created by dacaiguoguo on 2018/11/14.
//  Copyright © 2018 dacaiguoguo. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *logFileName = [NSString stringWithFormat:@"%@_%@.plist", [[NSProcessInfo processInfo] globallyUniqueString], @"XcodeRunDestinationHelper"];
        NSString *logFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:logFileName];
        NSString *command = [NSString stringWithFormat:@"defaults export com.apple.dt.Xcode %@", logFilePath];
        system(command.UTF8String);
        NSMutableDictionary *plistInfo = [NSMutableDictionary dictionaryWithContentsOfFile:logFilePath];
        NSString *logFileName2 = [NSString stringWithFormat:@"%@_%@.json", [[NSProcessInfo processInfo] globallyUniqueString], @"XcodeRunDestinationHelper2"];
        NSString *logFilePath2 = [NSTemporaryDirectory() stringByAppendingPathComponent:logFileName2];
        NSString *command2 = [NSString stringWithFormat:@"xcrun simctl list -j > %@", logFilePath2];
        system("xcrun simctl delete unavailable");
        system(command2.UTF8String);
        NSMutableArray *ignoreDeviceIdArray = plistInfo[@"DVTIgnoredDevices"];
        
        NSData *jsonData = [NSData dataWithContentsOfFile:logFilePath2];
        NSDictionary *simList = [NSJSONSerialization JSONObjectWithData:jsonData options:(NSJSONReadingMutableContainers) error:nil];
        NSDictionary<NSString *, NSArray *> *allDevicesInfo = simList[@"devices"];
        NSMutableArray *devicesIdArray = [NSMutableArray array];
        [allDevicesInfo enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSDictionary<NSString *, NSString *> *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull obj2, NSUInteger idx2, BOOL * _Nonnull stop2) {
                [devicesIdArray addObject:obj2[@"udid"]];
                if (![ignoreDeviceIdArray containsObject:obj2[@"udid"]]) {
                    [ignoreDeviceIdArray addObject:obj2[@"udid"]];
                }
            }];
        }];
//        NSLog(@"%@", ignoreDeviceIdArray);
        NSString *logFileresultName = [NSString stringWithFormat:@"%@_%@_result.plist", [[NSProcessInfo processInfo] globallyUniqueString], @"XcodeRunDestinationHelper"];
        NSString *logFilePath3 = [NSTemporaryDirectory() stringByAppendingPathComponent:logFileresultName];
        BOOL ret = [plistInfo writeToFile:logFilePath3 atomically:YES];
        assert(ret);
        NSString *command3 = [NSString stringWithFormat:@"defaults import com.apple.dt.Xcode %@", logFilePath3];
        int retNumber =   system(command3.UTF8String);
        assert(retNumber == 0);
        NSLog(@"had clean all simulator devices");
    }
    return 0;
}
