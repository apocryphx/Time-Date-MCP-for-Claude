//
//  main.m
//  ESTimeDateMCP
//
//  Created by Kolja Wawrowsky on 4/13/26.
//
//  Standalone stdio MCP server providing current date/time.
//  Claude Desktop launches this as a subprocess — reads JSON-RPC from stdin,
//  writes responses to stdout.
//

#import <Foundation/Foundation.h>
#include <signal.h>

#pragma mark - Tool Implementation

static NSDictionary *ExecuteGetCurrentDatetime(void) {
    NSDate *now = [NSDate date];
    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSCalendar *cal = [NSCalendar currentCalendar];

    NSDateFormatter *iso = [[NSDateFormatter alloc] init];
    iso.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    iso.timeZone = tz;

    NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
    dateFmt.dateFormat = @"yyyy-MM-dd";
    dateFmt.timeZone = tz;

    NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
    timeFmt.dateFormat = @"HH:mm:ss";
    timeFmt.timeZone = tz;

    NSDateComponents *comps = [cal components:(NSCalendarUnitWeekday | NSCalendarUnitWeekOfYear |
                                               NSCalendarUnitYear | NSCalendarUnitMonth |
                                               NSCalendarUnitDay | NSCalendarUnitHour |
                                               NSCalendarUnitMinute | NSCalendarUnitSecond)
                                     fromDate:now];

    NSArray *dayNames = @[@"", @"Sunday", @"Monday", @"Tuesday", @"Wednesday",
                          @"Thursday", @"Friday", @"Saturday"];

    return @{
        @"iso8601": [iso stringFromDate:now],
        @"date": [dateFmt stringFromDate:now],
        @"time": [timeFmt stringFromDate:now],
        @"day_of_week": dayNames[comps.weekday],
        @"timezone": tz.name,
        @"timezone_abbreviation": tz.abbreviation ?: @"",
        @"utc_offset_seconds": @(tz.secondsFromGMT),
        @"utc_offset": [NSString stringWithFormat:@"%+03ld:%02ld",
                        (long)(tz.secondsFromGMT / 3600),
                        (long)(labs(tz.secondsFromGMT) % 3600 / 60)],
        @"unix_timestamp": @((long long)[now timeIntervalSince1970])
    };
}

#pragma mark - MCP Protocol Handling

static NSDictionary *HandleInitialize(NSDictionary *params) {
    NSString *clientVersion = params[@"protocolVersion"];
    NSSet *supported = [NSSet setWithArray:@[@"2024-11-05", @"2025-03-26", @"2025-06-18", @"2025-11-25", @"2026-03-26"]];
    NSString *negotiated = (clientVersion && [supported containsObject:clientVersion])
        ? clientVersion : @"2026-03-26";

    return @{
        @"protocolVersion": negotiated,
        @"capabilities": @{
            @"tools": @{}
        },
        @"serverInfo": @{
            @"name": @"ESTimeDateMCP",
            @"version": @"1.0.0"
        }
    };
}

static NSDictionary *HandleToolsList(void) {
    return @{@"tools": @[
        @{
            @"name": @"get_current_datetime",
            @"description": @"Returns the current date, time, timezone, day of week, "
                             "and Unix timestamp from the user's local machine.",
            @"inputSchema": @{
                @"type": @"object",
                @"properties": @{},
                @"required": @[]
            },
            @"annotations": @{
                @"title": @"Get Current Date & Time",
                @"readOnlyHint": @YES,
                @"destructiveHint": @NO,
                @"idempotentHint": @YES,
                @"openWorldHint": @NO
            }
        }
    ]};
}

static NSDictionary *HandleToolsCall(NSDictionary *params) {
    NSString *toolName = params[@"name"];

    if ([toolName isEqualToString:@"get_current_datetime"]) {
        NSDictionary *result = ExecuteGetCurrentDatetime();
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
        NSString *text = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return @{@"content": @[@{@"type": @"text", @"text": text ?: @"{}"}]};
    }

    return nil;
}

static NSDictionary *DispatchMethod(NSString *method, NSDictionary *params, NSError **outError) {
    if ([method isEqualToString:@"initialize"]) {
        return HandleInitialize(params);
    }
    if ([method isEqualToString:@"ping"]) {
        return @{};
    }
    if ([method isEqualToString:@"tools/list"]) {
        return HandleToolsList();
    }
    if ([method isEqualToString:@"tools/call"]) {
        NSDictionary *result = HandleToolsCall(params);
        if (!result) {
            if (outError) {
                *outError = [NSError errorWithDomain:@"MCPError" code:-32602
                    userInfo:@{NSLocalizedDescriptionKey:
                        [NSString stringWithFormat:@"Unknown tool: %@", params[@"name"]]}];
            }
            return nil;
        }
        return result;
    }

    if ([method hasPrefix:@"notifications/"]) {
        return nil;
    }

    if (outError) {
        *outError = [NSError errorWithDomain:@"MCPError" code:-32601
            userInfo:@{NSLocalizedDescriptionKey: @"Method not found"}];
    }
    return nil;
}

#pragma mark - JSON-RPC Helpers

static NSString *JSONRPCResponse(id rpcId, NSDictionary *result) {
    NSDictionary *response = @{
        @"jsonrpc": @"2.0",
        @"id": rpcId,
        @"result": result ?: @{}
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static NSString *JSONRPCError(id rpcId, NSInteger code, NSString *message) {
    NSDictionary *response = @{
        @"jsonrpc": @"2.0",
        @"id": rpcId ?: [NSNull null],
        @"error": @{
            @"code": @(code),
            @"message": message ?: @"Error"
        }
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

#pragma mark - Main

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);

        fprintf(stderr, "[ESTimeDateMCP] starting\n");

        NSFileHandle *stdinHandle = [NSFileHandle fileHandleWithStandardInput];
        NSFileHandle *stdoutHandle = [NSFileHandle fileHandleWithStandardOutput];
        NSMutableData *buffer = [NSMutableData data];
        NSData *newlineData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];

        __block BOOL stdinClosed = NO;

        stdinHandle.readabilityHandler = ^(NSFileHandle *handle) {
            NSData *chunk = [handle availableData];
            if (chunk.length == 0) {
                stdinClosed = YES;
                CFRunLoopStop(CFRunLoopGetMain());
                return;
            }

            [buffer appendData:chunk];

            while (YES) {
                NSRange newlineRange = [buffer rangeOfData:newlineData
                                                   options:0
                                                     range:NSMakeRange(0, buffer.length)];
                if (newlineRange.location == NSNotFound) break;

                NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, newlineRange.location)];
                [buffer replaceBytesInRange:NSMakeRange(0, newlineRange.location + 1)
                                  withBytes:NULL length:0];

                NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
                line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (line.length == 0) continue;

                NSError *parseError = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:&parseError];
                if (!json || ![json isKindOfClass:[NSDictionary class]]) {
                    NSString *err = JSONRPCError([NSNull null], -32700, @"Parse error");
                    if (err) {
                        [stdoutHandle writeData:[[err stringByAppendingString:@"\n"]
                            dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                    continue;
                }

                id rpcId = json[@"id"];
                NSString *method = json[@"method"];
                NSDictionary *params = json[@"params"] ?: @{};

                fprintf(stderr, "[ESTimeDateMCP] %s id=%s\n",
                        method.UTF8String ?: "(none)",
                        rpcId ? [[NSString stringWithFormat:@"%@", rpcId] UTF8String] : "(notification)");

                NSError *dispatchError = nil;
                NSDictionary *result = DispatchMethod(method, params, &dispatchError);

                if (!rpcId) continue;

                NSString *output;
                if (dispatchError) {
                    output = JSONRPCError(rpcId, dispatchError.code,
                                          dispatchError.localizedDescription);
                } else {
                    output = JSONRPCResponse(rpcId, result);
                }

                if (output) {
                    [stdoutHandle writeData:[[output stringByAppendingString:@"\n"]
                        dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
        };

        while (!stdinClosed) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
            }
        }

        fprintf(stderr, "[ESTimeDateMCP] stdin closed, exiting\n");
    }
    return EXIT_SUCCESS;
}
