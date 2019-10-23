//
//  main.m
//  XcodeRunDestinationHelper
//
//  Created by dacaiguoguo on 2018/11/14.
//  Copyright © 2018 dacaiguoguo. All rights reserved.
//

@import Foundation;

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
        int ret = 0;
//        NSString *device_setPath = [NSString stringWithFormat:@"%@/Library/Developer/CoreSimulator/Devices/device_set.plist", NSHomeDirectory()];
//        NSMutableDictionary *device_setInfo = [NSMutableDictionary dictionaryWithContentsOfFile:device_setPath];
//        NSDictionary *DefaultDevices = device_setInfo[@"DefaultDevices"];
//        NSDictionary<NSString *, NSString *> *iOS_12_1 = DefaultDevices[@"com.apple.CoreSimulator.SimRuntime.iOS-12-1"];
//        [iOS_12_1 enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
//            NSString *devideItem = [NSString stringWithFormat:@"%@/Library/Developer/CoreSimulator/Devices/%@", NSHomeDirectory(), obj];
//            NSLog(@"%@", devideItem);
//        }];
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
            obj[@"ChromeTint"] = @"#53d4a2"; //simulator color
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
        NSUInteger ignoreCount = ignoreDeviceIdArray.count;

        NSSet *keepSet = [NSSet setWithObjects:@"iPhone 11", @"iPhone 11 Pro", @"iPhone 11 Pro Max", @"iPhone SE", @"iPad Air (3rd generation)", nil];
//        NSSet *keepSet = [NSSet setWithObjects:@"562D22B9-B952-415F-A2A8-197B4975FE01", nil];
        //
        NSDictionary<NSString *, NSArray *> *allDevicesInfo = simList[@"devices"];
        [allDevicesInfo enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSDictionary<NSString *, NSString *> *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> * _Nonnull obj2, NSUInteger idx2, BOOL * _Nonnull stop2) {
                NSString *udid = obj2[@"udid"];

                if ([keepSet containsObject:obj2[@"name"]] || [keepSet containsObject:udid]) {
                    // skip
                    NSLog(@"Keep Device:%@ udid:%@", obj2[@"name"], udid);
                } else if (![ignoreDeviceIdArray containsObject:udid]) {
                    NSLog(@"add udid:%@", udid);
                    [ignoreDeviceIdArray addObject:udid];
                }
            }];
        }];
        NSFileManager *fn = [NSFileManager defaultManager];
        if (ignoreCount == ignoreDeviceIdArray.count) {
            [pathArray enumerateObjectsUsingBlock:^(NSString *aPath, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([fn fileExistsAtPath:aPath]) {
                    [fn removeItemAtPath:aPath error:nil];
                }
            }];
            NSLog(@"please restart Simulator");
            return 0;
        }

        NSString *newPlistPath = plistFilePathWithName(@"newxcodedefault");
        [pathArray addObject:newPlistPath];

        BOOL success = [plistInfo writeToFile:newPlistPath atomically:YES];
        assert(success);
        NSString *importXcodeCommand = [NSString stringWithFormat:@"defaults import com.apple.dt.Xcode %@", newPlistPath];
        ret = system(importXcodeCommand.UTF8String);
        if (ret != 0) {
            exit(ret);
        }

        [pathArray enumerateObjectsUsingBlock:^(NSString *aPath, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([fn fileExistsAtPath:aPath]) {
                [fn removeItemAtPath:aPath error:nil];
            }
        }];

        NSLog(@"please restart Xcode & Simulator");
    }
    return 0;
}
