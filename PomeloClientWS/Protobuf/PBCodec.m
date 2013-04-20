//
//  Codec.m
//  protobuf.codec
//
//  Created by ETiV on 13-4-15.
//  Copyright (c) 2013年 ETiV. All rights reserved.
//

#import "PBCodec.h"

@implementation PBCodec

+ (NSMutableData *)encodeUInt32:(uint32_t)n {
  unsigned char result[5] = {0}, count = 0;
  do {
    result[count++] = (unsigned char) ((n & 0x7F) | 0x80);
    n >>= 7;
  } while (n != 0);
  result[count - 1] &= 0x7F;
  return [NSMutableData dataWithBytes:result length:count];
  //log("encodeUInt32: 0x%@", dst);
}

+ (uint32_t)decodeUInt32:(NSData *)data {
  uint32_t n = 0;
  unsigned char *ptr = (unsigned char *) data.bytes;
  uint32_t i = 0;
  for (; i < data.length; i++) {
    n |= ((ptr[i] & 0x7F) << (i * 7));
  }
  //log("decodeUInt32: %u", n);
  return n;
}

+ (NSMutableData *)encodeSInt32:(int32_t)n {
  n = n < 0 ? (abs(n) * 2 - 1) : n * 2;
  return [PBCodec encodeUInt32:n];
  //log("encodeSInt32: %@", dst);
}

+ (int32_t)decodeSInt32:(NSData *)data {
  // even number means source number is >= 0
  // odd number means source number is < 0
  uint32_t n = [PBCodec decodeUInt32:data];
  bool isOddNumber = (bool) (n & 0x1);
  n >>= 1;
  //log("decodeSInt32: %d", ( (isOddNumber) ? (-1 * (n + 1)) : (n) ));
  return ((isOddNumber) ? (-1 * (n + 1)) : (n));
}

+ (NSMutableData *)encodeFloat:(float)n {
  union u {
    float f;
    int32_t i;
  };
  union u tmp;
  tmp.f = n;
  return [NSMutableData dataWithBytes:&(tmp.i) length:sizeof(float)];
  //log("encodeFloat: %@", dst);
}

+ (float)decodeFloat:(NSData *)data from:(NSUInteger)offset {
  if (data == nil || data.length < (offset + sizeof(float))) {
    return 0.0;
  }

  union u {
    float f;
    int32_t i;
  };
  union u tmp;
  tmp.i = *(int32_t *) &(data.bytes[offset]);
  //log("decodeFloat: %f", tmp.f);
  return tmp.f;
}

+ (NSMutableData *)encodeDouble:(double)n {
  union u {
    double d;
    int64_t i;
  };
  union u tmp;
  tmp.d = n;
  return [NSMutableData dataWithBytes:&(tmp.i) length:sizeof(double)];
  //log("encodeDouble: %@", dst);
}

+ (double)decodeDouble:(NSData *)data from:(NSUInteger)offset {
  if (data == nil || data.length < (offset + sizeof(double))) {
    return 0.0;
  }
  union u {
    double d;
    int64_t i;
  };
  union u tmp;
  tmp.i = *(int64_t *) &(data.bytes[offset]);
  //log("decodeDouble: %lf", tmp.d);
  return tmp.d;
}

+ (NSUInteger)encodeStr:(NSString *)str dst:(NSMutableData *)dst from:(NSUInteger)offset {
  NSData *strAsData = [str dataUsingEncoding:NSUTF8StringEncoding];
  [dst replaceBytesInRange:NSMakeRange(offset, [str length])
                 withBytes:strAsData.bytes
                    length:[str length]];
  return (offset + [strAsData length]);
//  [dst setData:[str dataUsingEncoding:NSUTF8StringEncoding]];
  //log("encodeStr: %@", dst);
}

+ (NSMutableString *)decodeStr:(NSData *)data from:(NSUInteger)offset withLength:(NSUInteger)length {
  return [[NSMutableString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, length)] encoding:NSUTF8StringEncoding];
  //log("decodeStr: %@", dst);
}

+ (unsigned long)byteLength:(NSString *)str {
  return [[str dataUsingEncoding:NSUTF8StringEncoding] length];
}

@end
