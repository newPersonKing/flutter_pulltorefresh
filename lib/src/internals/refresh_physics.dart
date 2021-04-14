/*
    Author: Jpeng
    Email: peng8350@gmail.com
    createTime:2018-05-02 14:39
 */
// ignore_for_file: INVALID_USE_OF_PROTECTED_MEMBER
// ignore_for_file: INVALID_USE_OF_VISIBLE_FOR_TESTING_MEMBER
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;

import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:pull_to_refresh/src/internals/slivers.dart';

/// a scrollPhysics for config refresh scroll effect,enable viewport out of edge whatever physics it is
/// in [ClampingScrollPhysics], it doesn't allow to flip out of edge,but in RefreshPhysics,it will allow to do that,
/// by parent physics passing,it also can attach the different of iOS and Android different scroll effect
/// it also handles interception scrolling when refreshed, or when the second floor is open and closed.
/// with [SpringDescription] passing,you can custom spring back animate,the more paramter can be setting in [RefreshConfiguration]
///
/// see also:
///
/// * [RefreshConfiguration], a configuration for Controlling how SmartRefresher widgets behave in a subtree
// ignore: MUST_BE_IMMUTABLE
class RefreshPhysics extends ScrollPhysics {
  final double maxOverScrollExtent, maxUnderScrollExtent;
  final double topHitBoundary, bottomHitBoundary;
  final SpringDescription springDescription;
  final double dragSpeedRatio;
  final bool enableScrollWhenTwoLevel, enableScrollWhenRefreshCompleted;
  final RefreshController controller;
  final int updateFlag;

  /// find out the viewport when bouncing,for compute the layoutExtent in header and footer
  /// This does not have any impact on performance. it only  execute once
  RenderViewport viewportRender;

  /// Creates scroll physics that bounce back from the edge.
  RefreshPhysics(
      {ScrollPhysics parent,
      this.updateFlag,
      this.maxUnderScrollExtent,
      this.springDescription,
      this.controller,
      this.dragSpeedRatio,
      this.topHitBoundary,
      this.bottomHitBoundary,
      this.enableScrollWhenRefreshCompleted,
      this.enableScrollWhenTwoLevel,
      this.maxOverScrollExtent})
      : super(parent: parent);

  /*忽略*/
  @override
  RefreshPhysics applyTo(ScrollPhysics ancestor) {
    return RefreshPhysics(
        parent: buildParent(ancestor),
        updateFlag: updateFlag,
        springDescription: springDescription,
        dragSpeedRatio: dragSpeedRatio,
        enableScrollWhenTwoLevel: enableScrollWhenTwoLevel,
        topHitBoundary: topHitBoundary,
        bottomHitBoundary: bottomHitBoundary,
        controller: controller,
        enableScrollWhenRefreshCompleted: enableScrollWhenRefreshCompleted,
        maxUnderScrollExtent: maxUnderScrollExtent,
        maxOverScrollExtent: maxOverScrollExtent);
  }

  RenderViewport findViewport(BuildContext context) {
    if (context == null) {
      return null;
    }
    RenderViewport result;
    context.visitChildElements((Element e) {
      final RenderObject renderObject = e.findRenderObject();
      if (renderObject is RenderViewport) {
        assert(result == null);
        result = renderObject;
      } else {
        result = findViewport(e);
      }
    });
    return result;
  }

  /*是否接收用户的事件*/
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // TODO: implement shouldAcceptUserOffset
    if (parent is NeverScrollableScrollPhysics) {
      return false;
    }
    return true;
  }

  //  It seem that it was odd to do so,but I have no choose to do this for updating the state value(enablePullDown and enablePullUp),
  // in Scrollable.dart _shouldUpdatePosition method,it use physics.runtimeType to check if the two physics is the same,this
  // will lead to whether the newPhysics should replace oldPhysics,If flutter can provide a method such as "shouldUpdate",
  // It can work perfectly.
  @override
  // TODO: implement runtimeType
  Type get runtimeType {
    if (updateFlag == 0) {
      return RefreshPhysics;
    } else {
      return BouncingScrollPhysics;
    }
  }

  /// offset 用户滑动的距离  向上滑动 offset 为负值 向下滑 offset 为正值
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // TODO: implement applyPhysicsToUserOffset
    viewportRender ??=
        findViewport(controller.position?.context?.storageContext);
    /*firstChild 与 lastChild 的类型是提前知道的*/
    // print("cccccccccccc====applyPhysicsToUserOffset==viewportRender?.firstChild===${viewportRender?.firstChild}");
    // print("cccccccccccc====applyPhysicsToUserOffset==viewportRender?.lastChild===${viewportRender?.lastChild}");
    /*controller.headerMode.value 的初始值 是RefreshStatus.idle*/
    /*继续向下拖动 状态更新为RefreshStatus.canRefresh*/
    if (controller.headerMode.value == RefreshStatus.twoLeveling) {
      if (offset > 0.0) {
        return parent.applyPhysicsToUserOffset(position, offset);
      }
    } else {
      /*如果 顶部或者底部 不存在 RenderSliverRefresh 或者  RenderSliverLoading 直接交给parent 处理 也就是原始逻辑*/
      if ((offset > 0.0 &&
              viewportRender?.firstChild is! RenderSliverRefresh) ||
          (offset < 0 && viewportRender?.lastChild is! RenderSliverLoading)) {
        return parent.applyPhysicsToUserOffset(position, offset);
      }
    }
    // print("cccccccccccc====applyPhysicsToUserOffset==offset===${offset}");
    // print("ccccccccccc===applyPhysicsToUserOffset==position.outOfRange====${position.outOfRange}");
    // print("ccccccccccc===applyPhysicsToUserOffset==position.minScrollExtent====${position.minScrollExtent}");
    // print("ccccccccccc===applyPhysicsToUserOffset==controller.headerMode.value====${controller.headerMode.value}");
    // print("ccccccccccc===applyPhysicsToUserOffset==position.pixels====${position.pixels}");
    // print("=============================================================");
    /*一般刷新 都会走这里*/
    if (position.outOfRange ||
        controller.headerMode.value == RefreshStatus.twoLeveling) {
      /*todo position.minScrollExtent 这个值正常情况下是 0 */
      final double overscrollPastStart =
          math.max(position.minScrollExtent - position.pixels, 0.0);
      final double overscrollPastEnd = math.max(
          position.pixels -
              (controller.headerMode.value == RefreshStatus.twoLeveling
                  ? 0.0
                  : position.maxScrollExtent),
          0.0);
      final double overscrollPast =
          math.max(overscrollPastStart, overscrollPastEnd);
      final bool easing = (overscrollPastStart > 0.0 && offset < 0.0) ||
          (overscrollPastEnd > 0.0 && offset > 0.0);

      /*这里计算 位移 展示有阻力的感觉*/
      final double friction = easing
          // Apply less resistance when easing the overscroll vs tensioning.
          ? frictionFactor(
              (overscrollPast - offset.abs()) / position.viewportDimension)
          : frictionFactor(overscrollPast / position.viewportDimension);
      final double direction = offset.sign;
      return direction *
          _applyFriction(overscrollPast, offset.abs(), friction) *
          (dragSpeedRatio ?? 1.0);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  static double _applyFriction(
      double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) return absDelta * gamma;
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  double frictionFactor(double overscrollFraction) =>
      0.52 * math.pow(1 - overscrollFraction, 2);

  /*定义到达边界的规则*/
  /*在更新 位置以前 回调*/
  /*value 参数 是当前的位移总量*/
  /*todo 这里返回的值 会添加到位移上去*/
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // print("cccccccc=====applyBoundaryConditions====controller.headerMode.value==${controller.headerMode.value}");
    // print("cccccccc=====applyBoundaryConditions====value==${value}");
    final ScrollPosition scrollPosition = position;
    viewportRender ??=
        findViewport(controller.position?.context?.storageContext);
    /*notFull 有没有充满一屏幕*/
    bool notFull = position.minScrollExtent == position.maxScrollExtent;
    /*确定是否支持 上拉加载 下拉刷新*/
    final bool enablePullDown = viewportRender == null
        ? false
        : viewportRender.firstChild is RenderSliverRefresh;
    final bool enablePullUp = viewportRender == null
        ? false
        : viewportRender.lastChild is RenderSliverLoading;

    if (controller.headerMode.value == RefreshStatus.twoLeveling) {
      if (position.pixels - value > 0.0) {
        return parent.applyBoundaryConditions(position, value);
      }
    } else {
      if ((position.pixels - value > 0.0 && !enablePullDown) ||
          (position.pixels - value < 0 && !enablePullUp)) {
        return parent.applyBoundaryConditions(position, value);
      }
    }

    double topExtra = 0.0;
    double bottomExtra = 0.0;
    if (enablePullDown) {
      final RenderSliverRefresh sliverHeader = viewportRender.firstChild;
      topExtra = sliverHeader.hasLayoutExtent
          ? 0.0
          : sliverHeader.refreshIndicatorLayoutExtent;
    }
    if (enablePullUp) {
      final RenderSliverLoading sliverFooter = viewportRender.lastChild;
      bottomExtra = (!notFull && sliverFooter.geometry.scrollExtent != 0) ||
              (notFull &&
                  controller.footerStatus == LoadStatus.noMore &&
                  !RefreshConfiguration.of(
                          controller.position.context.storageContext)
                      .enableLoadingWhenNoData) ||
              (notFull &&
                  (RefreshConfiguration.of(
                              controller.position.context.storageContext)
                          .hideFooterWhenNotFull ??
                      false))
          ? 0.0
          : sliverFooter.layoutExtent;
    }

    final double topBoundary =
        position.minScrollExtent - maxOverScrollExtent - topExtra;
    final double bottomBoundary =
        position.maxScrollExtent + maxUnderScrollExtent + bottomExtra;

    if (scrollPosition.activity is BallisticScrollActivity) {
      if (topHitBoundary != double.infinity) {
        if (value < -topHitBoundary && -topHitBoundary < position.pixels) {
          // hit top edge
          return value + topHitBoundary;
        }
      }
      if (bottomHitBoundary != double.infinity) {
        if (position.pixels < bottomHitBoundary + position.maxScrollExtent &&
            bottomHitBoundary + position.maxScrollExtent < value) {
          // hit bottom edge
          return value - bottomHitBoundary - position.maxScrollExtent;
        }
      }
    }
    if (maxOverScrollExtent != double.infinity &&
        value < topBoundary &&
        topBoundary < position.pixels) // hit top edge
      return value - topBoundary;
    if (maxUnderScrollExtent != double.infinity &&
        position.pixels < bottomBoundary &&
        bottomBoundary < value) {
      // hit bottom edge
      return value - bottomBoundary;
    }

    print("applyBoundaryConditions=====scrollPosition.activity=====${scrollPosition.activity}");
    print("applyBoundaryConditions=====maxOverScrollExtent=====${maxOverScrollExtent}");
    print("applyBoundaryConditions=====maxUnderScrollExtent=====${maxUnderScrollExtent}");
    // check user is dragging,it is import,some devices may not bounce with different frame and time,bouncing return the different velocity
    if (scrollPosition.activity is DragScrollActivity) {
      if (maxOverScrollExtent != double.infinity &&
          value < position.pixels &&
          position.pixels <= topBoundary) // underscroll value < position.pixels 代表向下滑动  position.pixels <= topBoundary 代表没有达到顶部边界
        return value - position.pixels;
      if (maxUnderScrollExtent != double.infinity &&
          bottomBoundary <= position.pixels &&
          position.pixels < value) // overscroll  bottomBoundary <= position.pixels 代表还没达到自己的边界 position.pixels < value 代表是向上滑动
        return value - position.pixels;
    }
    print("applyBoundaryConditions=====result");
    return 0.0;
  }

  @override
  Simulation createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // TODO: implement createBallisticSimulation
    viewportRender ??=
        findViewport(controller.position?.context?.storageContext);

    final bool enablePullDown = viewportRender == null
        ? false
        : viewportRender.firstChild is RenderSliverRefresh;
    final bool enablePullUp = viewportRender == null
        ? false
        : viewportRender.lastChild is RenderSliverLoading;
    if (controller.headerMode.value == RefreshStatus.twoLeveling) {
      if (velocity < 0.0) {
        return parent.createBallisticSimulation(position, velocity);
      }
    } else if (!position.outOfRange) {
      if ((velocity < 0.0 && !enablePullDown) ||
          (velocity > 0 && !enablePullUp)) {
        return parent.createBallisticSimulation(position, velocity);
      }
    }
    if ((position.pixels > 0 &&
            controller.headerMode.value == RefreshStatus.twoLeveling) ||
        position.outOfRange) {
      return BouncingScrollSimulation(
        spring: springDescription ?? spring,
        position: position.pixels,
        // -1.0 avoid stop springing back ,and release gesture
        velocity: velocity * 0.91,
        // TODO(abarth): We should move this constant closer to the drag end.
        leadingExtent: position.minScrollExtent,
        trailingExtent: controller.headerMode.value == RefreshStatus.twoLeveling
            ? 0.0
            : position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
