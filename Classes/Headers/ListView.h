// Created by Satoshi Nakagawa <psychs AT limechat DOT net> <http://github.com/psychs/limechat>
// You can redistribute it and/or modify it under the new BSD license.

@interface ListView : NSOutlineView
{
	id keyDelegate;
	id textDelegate;
}

@property (nonatomic, assign) id keyDelegate;
@property (nonatomic, assign) id textDelegate;

- (NSInteger)countSelectedRows;
- (void)selectItemAtIndex:(NSInteger)index;
- (void)selectRows:(NSArray *)indices;
- (void)selectRows:(NSArray *)indices extendSelection:(BOOL)extend;
@end

@interface NSObject (ListViewDelegate)
- (void)listViewDelete;
- (void)listViewMoveUp;
- (void)listViewKeyDown:(NSEvent *)e;
@end