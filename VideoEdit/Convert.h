//
//  Convert.h
//  DF
//
//  Created by 刘东旭 on 2021/12/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Convert : NSObject

- (instancetype)init:(NSString *)filePath;

- (void)convert;

@end

NS_ASSUME_NONNULL_END
