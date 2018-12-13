//
//  main.m
//  XcodeRunDestinationHelper
//
//  Created by dacaiguoguo on 2018/11/14.
//  Copyright © 2018 dacaiguoguo. All rights reserved.
//

#import <Foundation/Foundation.h>
NSString *logFilePathWithNameAndExt(NSString *fileName, NSString *ext) {
    NSString *logFileName = [NSString stringWithFormat:@"%@_%@.%@", [[NSProcessInfo processInfo] globallyUniqueString], [@"XcodeRunDestinationHelper_" stringByAppendingString:fileName], ext?:@""];
    NSString *logFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:logFileName];
    return logFilePath;
}

NSString *plistFilePathWithName(NSString *fileName) {
    NSString *logFilePath = logFilePathWithNameAndExt(fileName, @"plist");
    return logFilePath;
}



int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray<NSString *> *pathArray = [NSMutableArray array];
        short ret = 0;

        NSString *simulatorPlistPath = plistFilePathWithName(@"iphonesimulator");
        [pathArray addObject:simulatorPlistPath];

        NSString *exportSimulatorDefaultsCommand = [NSString stringWithFormat:@"defaults export com.apple.iphonesimulator %@", simulatorPlistPath];
        ret = system(exportSimulatorDefaultsCommand.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        NSMutableDictionary *simulatorPlistInfo = [NSMutableDictionary dictionaryWithContentsOfFile:simulatorPlistPath];
        simulatorPlistInfo[@"ShowSingleTouches"] = @(1);
        simulatorPlistInfo[@"AllowFullscreenMode"] = @(1);


        NSMutableDictionary<NSString *,NSMutableDictionary<NSString *, NSString *> *> *devicePreferences = simulatorPlistInfo[@"DevicePreferences"];
        [devicePreferences enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableDictionary<NSString *,NSString *> *obj, BOOL *stop) {
            obj[@"ChromeTint"] = @"#c0c0c0"; //simulator color
        }];

        NSString *newSimulatorPlistPath = plistFilePathWithName(@"newiphonesimulator");
        [pathArray addObject:newSimulatorPlistPath];
        [simulatorPlistInfo writeToFile:newSimulatorPlistPath atomically:YES];

        NSString *importSimulatorDefaultsCommand = [NSString stringWithFormat:@"defaults import com.apple.iphonesimulator %@", newSimulatorPlistPath];
        ret = system(importSimulatorDefaultsCommand.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        NSString *plistPath = plistFilePathWithName(@"xcodedefault");
        [pathArray addObject:plistPath];

        NSString *command = [NSString stringWithFormat:@"defaults export com.apple.dt.Xcode %@", plistPath];
        ret = system(command.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        ret = system("xcrun simctl delete unavailable");
        if (ret != 0) {
            exit(ret);
        }

        NSString *jsonPath = logFilePathWithNameAndExt(@"devices", @"json");
        [pathArray addObject:jsonPath];

        NSString *command2Json = [NSString stringWithFormat:@"xcrun simctl list -j > %@", jsonPath]; // 'xcrun xcdevice list' also ok
        ret = system(command2Json.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        if (jsonData.length == 0) {
            exit(ret);
        }
        NSDictionary *simList = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];


        NSMutableDictionary *plistInfo = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
        NSMutableArray *ignoreDeviceIdArray = plistInfo[@"DVTIgnoredDevices"];

        NSDictionary<NSString *, NSArray *> *allDevicesInfo = simList[@"devices"];
        [allDevicesInfo enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSDictionary<NSString *, NSString *> *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull obj2, NSUInteger idx2, BOOL * _Nonnull stop2) {
                NSString *udid = obj2[@"udid"];
                if (![ignoreDeviceIdArray containsObject:udid]) {
                    NSLog(@"add udid:%@", udid);
                    [ignoreDeviceIdArray addObject:udid];
                }
            }];
        }];
        NSString *newPlistPath = plistFilePathWithName(@"newxcodedefault");
        [pathArray addObject:newPlistPath];

        BOOL success = [plistInfo writeToFile:newPlistPath atomically:YES];
        assert(success);
        NSString *importXcodeCommand = [NSString stringWithFormat:@"defaults import com.apple.dt.Xcode %@", newPlistPath];
        ret = system(importXcodeCommand.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        NSFileManager *fn = [NSFileManager defaultManager];
        [pathArray enumerateObjectsUsingBlock:^(NSString *aPath, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([fn fileExistsAtPath:aPath]) {
                [fn removeItemAtPath:aPath error:nil];
            }
        }];
        NSLog(@"please restart Xcode & Simulator");
    }
    return 0;
}
