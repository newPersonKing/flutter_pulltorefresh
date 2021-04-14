/*
 * Author: Jpeng
 * Email: peng8350@gmail.com
 * Time: 2019/5/2 下午5:09
 */

import 'package:flutter/widgets.dart';
import 'dart:math' as Math;
import 'package:flutter/rendering.dart';
import '../smart_refresher.dart';

///  Render header sliver widget
class SliverRefresh extends SingleChildRenderObjectWidget {
  const SliverRefresh({
    Key key,
    this.paintOffsetY,
    this.refreshIndicatorLayoutExtent = 0.0,
    this.floating = false,
    Widget child,
    this.refreshStyle,
  })  : assert(refreshIndicatorLayoutExtent != null),
        assert(refreshIndicatorLayoutExtent >= 0.0),
        assert(floating != null),
        super(key: key, child: child);

  /// The amount of space the indicator should occupy in the sliver in a
  /// resting state when in the refreshing mode.
  final double refreshIndicatorLayoutExtent;

  /// _RenderSliverRefresh will paint the child in the available
  /// space either way but this instructs the _RenderSliverRefresh
  /// on whether to also occupy any layoutExtent space or not.
  final bool floating;

  /// header indicator display style
  final RefreshStyle refreshStyle;

  /// headerOffset	Head indicator layout deviation Y coordinates, mostly for FrontStyle
  final double paintOffsetY;

  @override
  RenderSliverRefresh createRenderObject(BuildContext context) {
    return RenderSliverRefresh(
      refreshIndicatorExtent: refreshIndicatorLayoutExtent,
      hasLayoutExtent: floating,
      paintOffsetY: paintOffsetY,
      refreshStyle: refreshStyle,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderSliverRefresh renderObject) {
    final RefreshStatus mode =
        SmartRefresher.of(context).controller.headerMode.value;
    renderObject
      ..refreshIndicatorLayoutExtent = refreshIndicatorLayoutExtent
      ..hasLayoutExtent = floating
      ..context = context
      ..refreshStyle = refreshStyle
      ..updateFlag = mode == RefreshStatus.twoLevelOpening ||
          mode == RefreshStatus.twoLeveling ||
          mode == RefreshStatus.idle
      ..paintOffsetY = paintOffsetY;
  }
}

class RenderSliverRefresh extends RenderSliverSingleBoxAdapter {
  RenderSliverRefresh(
      {@required double refreshIndicatorExtent,
      @required bool hasLayoutExtent,
      RenderBox child,
      this.paintOffsetY,
      this.refreshStyle})
      : assert(refreshIndicatorExtent != null),
        assert(refreshIndicatorExtent >= 0.0),
        assert(hasLayoutExtent != null),
        _refreshIndicatorExtent = refreshIndicatorExtent,
        _hasLayoutExtent = hasLayoutExtent {
    this.child = child;
  }

  RefreshStyle refreshStyle;
  BuildContext context;

  // The amount of layout space the indicator should occupy in the sliver in a
  // resting state when in the refreshing mode.
  double get refreshIndicatorLayoutExtent => _refreshIndicatorExtent;
  double _refreshIndicatorExtent;
  double paintOffsetY;
  // need to trigger shouldAceppty user offset ,else it will not limit scroll when enter twolevel or exit
  // also it will crash if you call applyNewDimession when the state change
  // I don't know why flutter limit it, no choice
  bool _updateFlag = false;

  set refreshIndicatorLayoutExtent(double value) {
    assert(value != null);
    assert(value >= 0.0);
    if (value == _refreshIndicatorExtent) return;
    _refreshIndicatorExtent = value;
    markNeedsLayout();
  }

  // The child box will be laid out and painted in the available space either
  // way but this determines whether to also occupy any
  // [SliverGeometry.layoutExtent] space or not.
  bool get hasLayoutExtent => _hasLayoutExtent;
  bool _hasLayoutExtent;

  set hasLayoutExtent(bool value) {
    assert(value != null);
    if (value == _hasLayoutExtent) return;
    if (!value) {
      _updateFlag = true;
    }
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  // This keeps track of the previously applied scroll offsets to the scrollable
  // so that when [refreshIndicatorLayoutExtent] or [hasLayoutExtent] changes,
  // the appropriate delta can be applied to keep everything in the same place
  // visually.
  double layoutExtentOffsetCompensation = 0.0;

  @override
  void performResize() {
    // TODO: implement performResize
    super.performResize();
  }

  /*todo 这个方法的含义 ？？？？？？*/
  @override
  // TODO: implement centerOffsetAdjustment
  double get centerOffsetAdjustment {
    if (refreshStyle == RefreshStyle.Front) {
      final RenderViewportBase renderViewport = parent;
      return Math.max(0.0, -renderViewport.offset.pixels);
    }
    return 0.0;
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    // TODO: implement layout
    if (refreshStyle == RefreshStyle.Front) {
      final RenderViewportBase renderViewport = parent;
      /*todo gy 设置偏移 滑动距离？？*/
      super.layout(
          (constraints as SliverConstraints)
              .copyWith(overlap: Math.min(0.0, renderViewport.offset.pixels)),
          parentUsesSize: true);
    } else {
      super.layout(constraints, parentUsesSize: parentUsesSize);
    }
  }

  set updateFlag(u) {
    _updateFlag = u;
    markNeedsLayout();
  }

  @override
  void debugAssertDoesMeetConstraints() {
    assert(geometry.debugAssertIsValid(informationCollector: () sync* {
      yield describeForError(
          'The RenderSliver that returned the offending geometry was');
    }));
    assert(() {
      if (geometry.paintExtent > constraints.remainingPaintExtent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'SliverGeometry has a paintOffset that exceeds the remainingPaintExtent from the constraints.'),
          describeForError(
              'The render object whose geometry violates the constraints is the following'),
          null,
          ErrorDescription(
            'The paintExtent must cause the child sliver to paint within the viewport, and so '
            'cannot exceed the remainingPaintExtent.',
          ),
        ]);
      }
      return true;
    }());
  }

  @override
  void performLayout() {
    if (_updateFlag) {
      // ignore_for_file: INVALID_USE_OF_PROTECTED_MEMBER
      // ignore_for_file: INVALID_USE_OF_VISIBLE_FOR_TESTING_MEMBER
      /*todo ScrollActivity 是何方神圣 ？？？？？*/
      Scrollable.of(context).position.activity.applyNewDimensions();
      _updateFlag = false;
    }
    // The new layout extent this sliver should now have.
    /*_hasLayoutExtent 这个值 是会变化的*/
    final double layoutExtent =
        (_hasLayoutExtent ? 1.0 : 0.0) * _refreshIndicatorExtent;
    // If the new layoutExtent instructive changed, the SliverGeometry's
    // layoutExtent will take that value (on the next performLayout run). Shift
    // the scroll offset first so it doesn't make the scroll position suddenly jump.
    if (refreshStyle != RefreshStyle.Front) {
      if (layoutExtent != layoutExtentOffsetCompensation) {
        geometry = SliverGeometry(
          scrollOffsetCorrection: layoutExtent - layoutExtentOffsetCompensation,
        );

        layoutExtentOffsetCompensation = layoutExtent;
        return;
      }
    }


    bool active = constraints.overlap < 0.0 || layoutExtent > 0.0;

    /*todo overscrolledExtent 多滑动的位移？？？？*/
    final double overscrolledExtent =
        -(parent as RenderViewportBase).offset.pixels;
    if (refreshStyle == RefreshStyle.Behind) {
      child.layout(
        constraints.asBoxConstraints(
            maxExtent: Math.max(0, overscrolledExtent + layoutExtent)),
        parentUsesSize: true,
      );
    } else
      child.layout(
        constraints.asBoxConstraints(),
        parentUsesSize: true,
      );
    final double boxExtent = (constraints.axisDirection == AxisDirection.up ||
            constraints.axisDirection == AxisDirection.down)
        ? child.size.height
        : child.size.width;

    if (active) {
      final double needPaintExtent = Math.min(
          Math.max(
            Math.max(
                    (constraints.axisDirection == AxisDirection.up ||
                            constraints.axisDirection == AxisDirection.down)
                        ? child.size.height
                        : child.size.width,
                    layoutExtent) -
                constraints.scrollOffset,
            0.0,
          ),
          constraints.remainingPaintExtent);

      // print("ccccccccccccccc====_hasLayoutExtent====$_hasLayoutExtent");
      // print("ccccccccccccccc====refreshStyle====$refreshStyle");
      // print("ccccccccccccccc====layoutExtent====$layoutExtent");
      // print("ccccccccccccccc====_refreshIndicatorExtent====$_refreshIndicatorExtent");
      // print("ccccccccccccccc====layoutExtentOffsetCompensation====$layoutExtentOffsetCompensation");
      // print("ccccccccccccccc====constraints.overlap====${constraints.overlap}");
      // print("ccccccccccccccc====constraints.scrollOffset====${constraints.scrollOffset}");
      // print("ccccccccccccccc====needPaintExtent====${needPaintExtent}");
      // print("ccccccccccccccc====overscrolledExtent====${overscrolledExtent}");
      // print("==========================================================");
      /*https://blog.csdn.net/sinat_17775997/article/details/106695244*/
      switch (refreshStyle) {
        case RefreshStyle.Follow:
          geometry = SliverGeometry(
            scrollExtent: layoutExtent, // sliver 可以滚动的范围，可以认为是 sliver 的高度（如果是 AxisDierction.Down）
            paintOrigin: -boxExtent - constraints.scrollOffset + layoutExtent,
            paintExtent: needPaintExtent, // 绘制范围
            hitTestExtent: needPaintExtent,
            hasVisualOverflow: overscrolledExtent < boxExtent, /*boxExtent child的高度 或者宽度*/ // 是否需要做clip，免得chidren溢出 整体滑动小于child 高度 需要裁减
            maxPaintExtent: needPaintExtent, // 最大绘制大小，必须 >= paintExtent
            layoutExtent: Math.min(needPaintExtent,
                Math.max(layoutExtent - constraints.scrollOffset, 0.0)),// 布局范围，当前 sliver 的 top 到下一个 sliver 的 top 的距离，范围是[0,paintExtent],默认是 paintExtent，会影响下一个 sliver 的 layout 位置
          );
          break;
        case RefreshStyle.Behind:
          geometry = SliverGeometry(
            scrollExtent: layoutExtent,
            paintOrigin: -overscrolledExtent - constraints.scrollOffset,
            paintExtent: needPaintExtent,
            maxPaintExtent: needPaintExtent,
            layoutExtent:
                Math.max(layoutExtent - constraints.scrollOffset, 0.0),
          );
          break;
        case RefreshStyle.UnFollow:
          geometry = SliverGeometry(
            scrollExtent: layoutExtent,
            paintOrigin: Math.min(
                -overscrolledExtent - constraints.scrollOffset,
                -boxExtent - constraints.scrollOffset + layoutExtent),
            paintExtent: needPaintExtent,
            hasVisualOverflow: overscrolledExtent < boxExtent,
            maxPaintExtent: needPaintExtent,
            layoutExtent: Math.min(needPaintExtent,
                Math.max(layoutExtent - constraints.scrollOffset, 0.0)),
          );

          break;
        case RefreshStyle.Front:
          geometry = SliverGeometry(
            paintOrigin: constraints.axisDirection == AxisDirection.up ||
                    constraints.crossAxisDirection == AxisDirection.left
                ? boxExtent
                : 0.0,
            visible: true,
            hasVisualOverflow: true,
          );
          break;
      }
      setChildParentData(child, constraints, geometry);
    } else {
      geometry = SliverGeometry.zero;
    }
  }

  @override
  void paint(PaintingContext paintContext, Offset offset) {
    paintContext.paintChild(child, Offset(offset.dx, offset.dy + paintOffsetY));
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}

/// Render footer sliver widget
class SliverLoading extends SingleChildRenderObjectWidget {
  /// when not full one page,whether it should be hide and disable loading
  final bool hideWhenNotFull;
  final bool floating;

  /// load state
  final LoadStatus mode;
  final double layoutExtent;

  /// when not full one page,whether it should follow content
  final bool shouldFollowContent;

  SliverLoading({
    Key key,
    this.mode,
    this.floating,
    this.shouldFollowContent,
    this.layoutExtent,
    this.hideWhenNotFull,
    Widget child,
  }) : super(key: key, child: child);

  @override
  RenderSliverLoading createRenderObject(BuildContext context) {
    return RenderSliverLoading(
        hideWhenNotFull: hideWhenNotFull,
        mode: mode,
        hasLayoutExtent: floating,
        shouldFollowContent: shouldFollowContent,
        layoutExtent: layoutExtent);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderSliverLoading renderObject) {
    renderObject
      ..mode = mode
      ..hasLayoutExtent = floating
      ..layoutExtent = layoutExtent
      ..shouldFollowContent = shouldFollowContent
      ..hideWhenNotFull = hideWhenNotFull;
  }
}

class RenderSliverLoading extends RenderSliverSingleBoxAdapter {
  RenderSliverLoading({
    RenderBox child,
    this.mode,
    double layoutExtent,
    bool hasLayoutExtent,
    this.shouldFollowContent,
    this.hideWhenNotFull,
  }) {
    _hasLayoutExtent = hasLayoutExtent;
    this.layoutExtent = layoutExtent;
    this.child = child;
  }

  bool shouldFollowContent;
  bool hideWhenNotFull;

  LoadStatus mode;

  double _layoutExtent;

  set layoutExtent(extent) {
    if (extent == _layoutExtent) return;
    _layoutExtent = extent;
    markNeedsLayout();
  }

  get layoutExtent => _layoutExtent;

  bool get hasLayoutExtent => _hasLayoutExtent;
  bool _hasLayoutExtent;

  set hasLayoutExtent(bool value) {
    assert(value != null);
    if (value == _hasLayoutExtent) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  bool _computeIfFull(SliverConstraints cons) {
    final RenderViewport viewport = parent;
    RenderSliver sliverP = viewport.firstChild;
    double totalScrollExtent = cons.precedingScrollExtent;
    while (sliverP != this) {
      if (sliverP is RenderSliverRefresh) {
        totalScrollExtent -= sliverP.geometry.scrollExtent;
        break;
      }
      sliverP = viewport.childAfter(sliverP);
    }
    // consider about footer layoutExtent,it should be subtracted it's height
    return totalScrollExtent >= cons.viewportMainAxisExtent;
  }

  //  many sitiuation: 1. reverse 2. not reverse
  // 3. follow content 4. unfollow content
  //5. not full 6. full
  double computePaintOrigin(double layoutExtent, bool reverse, bool follow) {
    if (follow) {
      if (reverse) {
        return layoutExtent;
      }
      return 0.0;
    } else {
      if (reverse) {
        return Math.max(
                constraints.viewportMainAxisExtent -
                    constraints.precedingScrollExtent,
                0.0) +
            layoutExtent;
      } else {
        return Math.max(
            constraints.viewportMainAxisExtent -
                constraints.precedingScrollExtent,
            0.0);
      }
    }
  }

  @override
  void debugAssertDoesMeetConstraints() {
    assert(geometry.debugAssertIsValid(informationCollector: () sync* {
      yield describeForError(
          'The RenderSliver that returned the offending geometry was');
    }));
    assert(() {
      if (geometry.paintExtent > constraints.remainingPaintExtent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'SliverGeometry has a paintOffset that exceeds the remainingPaintExtent from the constraints.'),
          describeForError(
              'The render object whose geometry violates the constraints is the following'),
          null,
          ErrorDescription(
            'The paintExtent must cause the child sliver to paint within the viewport, and so '
            'cannot exceed the remainingPaintExtent.',
          ),
        ]);
      }
      return true;
    }());
  }

  @override
  void performLayout() {
    assert(constraints.growthDirection == GrowthDirection.forward);
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    bool active;
    if (hideWhenNotFull && mode != LoadStatus.noMore) {
      active = _computeIfFull(constraints);
    } else {
      active = true;
    }
    if (active) {
      child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    } else {
      child.layout(constraints.asBoxConstraints(maxExtent: 0.0, minExtent: 0.0),
          parentUsesSize: true);
    }
    double childExtent = constraints.axis == Axis.vertical
        ? child.size.height
        : child.size.width;
    assert(childExtent != null);
    final double paintedChildSize =
        calculatePaintOffset(constraints, from: 0.0, to: childExtent);
    final double cacheExtent =
        calculateCacheOffset(constraints, from: 0.0, to: childExtent);
    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    if (active) {
      // consider reverse loading and HideAlways==loadStyle
      geometry = SliverGeometry(
        scrollExtent: !_hasLayoutExtent || !_computeIfFull(constraints)
            ? 0
            : layoutExtent,
        paintExtent: paintedChildSize,
        // this need to fix later
        paintOrigin: computePaintOrigin(
            !_hasLayoutExtent || !_computeIfFull(constraints)
                ? layoutExtent
                : 0.0,
            constraints.axisDirection == AxisDirection.up ||
                constraints.axisDirection == AxisDirection.left,
            _computeIfFull(constraints) || shouldFollowContent),
        cacheExtent: cacheExtent,
        maxPaintExtent: childExtent,
        hitTestExtent: paintedChildSize,
        visible: true,
        hasVisualOverflow: true,
      );
      setChildParentData(child, constraints, geometry);
    } else {
      geometry = SliverGeometry.zero;
    }
  }
}

/*只是为了生成sliver 所有的滑动都是sliver*/
class SliverRefreshBody extends SingleChildRenderObjectWidget {
  /// Creates a sliver that contains a single box widget.
  const SliverRefreshBody({
    Key key,
    Widget child,
  }) : super(key: key, child: child);

  @override
  RenderSliverRefreshBody createRenderObject(BuildContext context) =>
      RenderSliverRefreshBody();
}

class RenderSliverRefreshBody extends RenderSliverSingleBoxAdapter {
  /// Creates a [RenderSliver] that wraps a [RenderBox].
  RenderSliverRefreshBody({
    RenderBox child,
  }) : super(child: child);

  /*SliverConstraints 描述了 Viewport 和它内部的 Slivers 之间的布局信息*/
  @override
  void performLayout() {
    if (child == null) {
      /*geometry 当前sliver 占据的高度*/
      geometry = SliverGeometry.zero;
      return;
    }
    /*parentUsesSize 为true 代表parent 的尺寸信息 依赖于child*/
    /*作用是 在滚动的方向没有限制*/
    child.layout(constraints.asBoxConstraints(maxExtent: 1111111),
        parentUsesSize: true);
    /*todo 这里是计算child 高度 ？？？？*/
    double childExtent;
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child.size.width;
        break;
      case Axis.vertical:
        childExtent = child.size.height;
        break;
    }
    assert(childExtent != null);
    /*todo gy 貌似只有这里是自己定义的一些内容*/
    if (childExtent == 1111111) {
      /*设置为窗口 高度 减去 0.1*/
      child.layout(
          constraints.asBoxConstraints(
              maxExtent: constraints.viewportMainAxisExtent - 0.1),
          parentUsesSize: true);
    }
    switch (constraints.axis) {
      case Axis.horizontal:
        childExtent = child.size.width;
        break;
      case Axis.vertical:
        childExtent = child.size.height;
        break;
    }
    /*计算它的绘制范围*/
    final double paintedChildSize =
        calculatePaintOffset(constraints, from: 0.0, to: childExtent);
    /*计算它的缓存范围*/
    final double cacheExtent =
        calculateCacheOffset(constraints, from: 0.0, to: childExtent);

    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      scrollExtent: childExtent,
      paintExtent: paintedChildSize,
      cacheExtent: cacheExtent,
      maxPaintExtent: childExtent,
      hitTestExtent: paintedChildSize,
      hasVisualOverflow: childExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0.0,
    );
    setChildParentData(child, constraints, geometry);
  }

}
