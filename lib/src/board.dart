library stack_board;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:stack_board/src/helper/operat_state.dart';

import 'case_group/adaptive_text_case.dart';
import 'case_group/drawing_board_case.dart';
import 'case_group/item_case.dart';
import 'helper/case_style.dart';
import 'item_group/adaptive_text.dart';
import 'item_group/stack_board_item.dart';
import 'item_group/stack_drawing.dart';

import 'package:stack_board/src/item_group/adaptive_text.dart';

import 'package:stack_board/src/case_group/item_case.dart';

/// 层叠板
class StackBoard extends StatefulWidget {
  const StackBoard({
    Key? key,
    this.controller,
    this.background,
    this.caseStyle = const CaseStyle(),
    this.customBuilder,
    this.tapToCancelAllItem = false,
    this.tapItemToMoveTop = true,
    this.gap,
  }) : super(key: key);

  @override
  _StackBoardState createState() => _StackBoardState();
  final Offset? gap;

  /// 层叠版控制器
  final StackBoardController? controller;

  /// 背景
  final Widget? background;

  /// 操作框样式
  final CaseStyle? caseStyle;

  /// 自定义类型控件构建器
  final Widget? Function(StackBoardItem item)? customBuilder;

  /// 点击空白处取消全部选择（比较消耗性能，默认关闭）
  final bool tapToCancelAllItem;

  /// 点击item移至顶层
  final bool tapItemToMoveTop;
}

class _StackBoardState extends State<StackBoard> with SafeState<StackBoard> {
  /// 子控件列表
  late List<StackBoardItem> _children;

  /// 当前item所用id
  int _lastId = 0;

  /// 所有item的操作状态
  OperatState? _operatState;

  /// 生成唯一Key
  Key _getKey(int? id) => Key('StackBoardItem$id');

  Map<String, GlobalKey<_AdaptiveTextCaseState>> keyMap =
      <String, GlobalKey<_AdaptiveTextCaseState>>{};
  @override
  void initState() {
    super.initState();
    _children = <StackBoardItem>[];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller?._stackBoardState = this;
  }

  /// 添加一个
  void _add<T extends StackBoardItem>(StackBoardItem item) {
    if (_children.contains(item)) throw 'duplicate id';
    print(item.id);

    /// 生成globalkey
    final GlobalKey<_AdaptiveTextCaseState> globalkey =
        GlobalKey<_AdaptiveTextCaseState>();
    keyMap['_key${item.id.toString()}'] = globalkey;
    print(keyMap['_key${item.id}']);
    _children.add(item.copyWith(
      id: item.id ?? _lastId,
      caseStyle: item.caseStyle ?? widget.caseStyle,
    ));
    _lastId++;

    safeSetState(() {});
  }

  /// 移除指定id item
  void _remove(int? id) {
    _children.removeWhere((StackBoardItem b) => b.id == id);
    safeSetState(() {});
  }

  /// 将item移至顶层
  void _moveItemToTop(int? id) {
    if (id == null) return;

    final StackBoardItem item =
        _children.firstWhere((StackBoardItem i) => i.id == id);
    _children.removeWhere((StackBoardItem i) => i.id == id);
    _children.add(item);

    safeSetState(() {});
  }

  /// 排版
  void format(int? id) {
    if (id == null) return;

    final item = keyMap['_key${id}']?.currentState;
    final text = item?._text;
    if (text == null) return;
    String formatText = '';

    if (text.contains('\n')) {
      formatText = text.replaceAll('\n', '');
      print(formatText);
    } else {
      formatText = text.split('').join("\n");
    }

    keyMap['_key${id}']?.currentState?.updateText(formatText);

    safeSetState(() {});
  }

  /// 清理
  void _clear() {
    _children.clear();
    _lastId = 0;
    safeSetState(() {});
  }

  /// 取消全部选中
  void _unFocus() {
    _operatState = OperatState.complate;
    safeSetState(() {});
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      _operatState = null;
      safeSetState(() {});
    });
  }

  /// 删除动作
  Future<void> _onDel(StackBoardItem box) async {
    final bool del = (await box.onDel?.call()) ?? true;
    if (del) _remove(box.id);
  }

  @override
  Widget build(BuildContext context) {
    Widget _child;

    if (widget.background == null)
      _child = Stack(
        fit: StackFit.expand,
        children:
            _children.map((StackBoardItem box) => _buildItem(box)).toList(),
      );
    else
      _child = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.background!,
          ..._children.map((StackBoardItem box) => _buildItem(box)).toList(),
        ],
      );

    if (widget.tapToCancelAllItem) {
      _child = GestureDetector(
        onTap: _unFocus,
        child: _child,
      );
    }

    return _child;
  }

  /// 构建项
  Widget _buildItem(StackBoardItem item) {
    Widget child = ItemCase(
      key: keyMap['_key${item.id}'],
      child: Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        child: const Text(
            'unknow item type, please use customBuilder to build it'),
      ),
      onDel: () => _onDel(item),
      onTap: () => _moveItemToTop(item.id),
      caseStyle: item.caseStyle,
      operatState: _operatState,
    );

    if (item is AdaptiveText) {
      print(item.data);

      child = AdaptiveTextCase(
          key: keyMap['_key${item.id}'],
          adaptiveText: item.copyWith(),
          onDel: () => _onDel(item),
          onTap: () => _moveItemToTop(item.id),
          onFormat: () => format(item.id),
          operatState: _operatState,
          gap: widget.gap);
    } else if (item is StackDrawing) {
      child = DrawingBoardCase(
        key: _getKey(item.id),
        stackDrawing: item,
        onDel: () => _onDel(item),
        onTap: () => _moveItemToTop(item.id),
        operatState: _operatState,
      );
    } else {
      child = ItemCase(
        key: keyMap['_key${item.id}'],
        child: item.child,
        onDel: () => _onDel(item),
        onTap: () => _moveItemToTop(item.id),
        caseStyle: item.caseStyle,
        operatState: _operatState,
      );

      if (widget.customBuilder != null) {
        final Widget? customWidget = widget.customBuilder!.call(item);
        if (customWidget != null) return child = customWidget;
      }
    }

    return child;
  }
}

/// 控制器
class StackBoardController {
  _StackBoardState? _stackBoardState;

  /// 检查是否加载
  void _check() {
    if (_stackBoardState == null) throw '_stackBoardState is empty';
  }

  /// 添加一个
  void add<T extends StackBoardItem>(T item) {
    _check();
    _stackBoardState?._add<T>(item);
  }

  /// 移除
  void remove(int? id) {
    _check();
    _stackBoardState?._remove(id);
  }

  /// 清空选中
  void unFocus() {
    _check();
    _stackBoardState?._unFocus();
  }

  void moveItemToTop(int? id) {
    _check();
    _stackBoardState?._moveItemToTop(id);
  }

  /// 清理全部
  void clear() {
    _check();
    _stackBoardState?._clear();
  }

  /// 刷新
  void refresh() {
    _check();
    _stackBoardState?.safeSetState(() {});
  }

  /// 销毁
  void dispose() {
    _stackBoardState = null;
  }
}

/// 默认文本样式
const TextStyle _defaultStyle = TextStyle(fontSize: 20);

/// 自适应文本外壳
class AdaptiveTextCase extends StatefulWidget {
  const AdaptiveTextCase({
    Key? key,
    required this.adaptiveText,
    this.onDel,
    this.operatState,
    this.onTap,
    this.onFormat,
    this.gap,
  }) : super(key: key);

  @override
  _AdaptiveTextCaseState createState() => _AdaptiveTextCaseState();
  final void Function()? onFormat;

  final Offset? gap;

  /// 自适应文本对象
  final AdaptiveText adaptiveText;

  /// 移除拦截
  final void Function()? onDel;

  /// 点击回调
  final void Function()? onTap;

  /// 操作状态
  final OperatState? operatState;
}

class _AdaptiveTextCaseState extends State<AdaptiveTextCase>
    with SafeState<AdaptiveTextCase> {
  /// 是否正在编辑
  bool _isEditing = false;

  /// 文本内容
  late String _text = widget.adaptiveText.data;

  /// 输入框宽度
  double _textFieldWidth = 100;

  /// 文本样式
  TextStyle get _style => widget.adaptiveText.style ?? _defaultStyle;

  /// 计算文本大小
  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  updateText(String v) {
    _text = v;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ItemCase(
      gap: widget.gap,
      isCenter: false,
      canEdit: true,
      onTap: widget.onTap,
      tapToEdit: widget.adaptiveText.tapToEdit,
      child: _isEditing ? _buildEditingBox : _buildTextBox,
      onDel: widget.onDel,
      onFormat: widget.onFormat,
      operatState: widget.operatState,
      caseStyle: widget.adaptiveText.caseStyle,
      onOperatStateChanged: (OperatState s) {
        if (s != OperatState.editing && _isEditing) {
          safeSetState(() => _isEditing = false);
        } else if (s == OperatState.editing && !_isEditing) {
          safeSetState(() => _isEditing = true);
        }

        return;
      },
      onSizeChanged: (Size s) {
        final Size size = _textSize(_text, _style);
        _textFieldWidth = size.width + 8;

        return;
      },
    );
  }

  /// 仅文本
  Widget get _buildTextBox {
    return FittedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          _text,
          style: _style,
          textAlign: widget.adaptiveText.textAlign,
          textDirection: widget.adaptiveText.textDirection,
          locale: widget.adaptiveText.locale,
          softWrap: widget.adaptiveText.softWrap,
          overflow: widget.adaptiveText.overflow,
          textScaleFactor: widget.adaptiveText.textScaleFactor,
          maxLines: widget.adaptiveText.maxLines,
          semanticsLabel: widget.adaptiveText.semanticsLabel,
        ),
      ),
    );
  }

  /// 正在编辑
  Widget get _buildEditingBox {
    return FittedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: _textFieldWidth,
          child: TextFormField(
            autofocus: true,
            initialValue: _text,
            onChanged: (String v) => _text = v,
            style: _style,
            textAlign: widget.adaptiveText.textAlign ?? TextAlign.start,
            textDirection: widget.adaptiveText.textDirection,
            maxLines: widget.adaptiveText.maxLines,
          ),
        ),
      ),
    );
  }
}
