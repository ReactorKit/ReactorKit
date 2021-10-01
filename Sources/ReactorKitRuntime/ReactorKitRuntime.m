#import <objc/runtime.h>
#import "ReactorKitRuntime.h"

@implementation NSObject (ReactorKit)

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self swizzleViewDidLoadOfClassNamed:@"UIViewController"];
    #if !TARGET_OS_MACCATALYST
    [self swizzleViewDidLoadOfClassNamed:@"NSViewController"];
    #endif
  });
}

+ (void)swizzleViewDidLoadOfClassNamed:(NSString *)className {
  Class class = NSClassFromString(className);
  if (!class) {
    return;
  }
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wundeclared-selector"
  SEL oldSelector = @selector(viewDidLoad);
  SEL performBindingSelector = @selector(_reactorkit_performBinding);
  #pragma clang diagnostic pop

  Method oldMethod = class_getInstanceMethod(class, oldSelector);
  const char *types = method_getTypeEncoding(oldMethod);
  void (*oldMethodImp)(id, SEL) = (void (*)(id, SEL))method_getImplementation(oldMethod);

  IMP newMethodImp = imp_implementationWithBlock(^(__unsafe_unretained id self) {
    oldMethodImp(self, oldSelector);
    if ([self respondsToSelector:performBindingSelector]) {
      #pragma clang diagnostic push
      #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
      [self performSelector:performBindingSelector];
      #pragma clang diagnostic pop
    }
  });
  class_replaceMethod(class, oldSelector, newMethodImp, types);
}

+ (BOOL)isSubclassOfClassNamed:(NSString *)className {
  Class superclass = NSClassFromString(className);
  if (!superclass) {
    return NO;
  }
  return [self isSubclassOfClass:superclass];
}

@end
