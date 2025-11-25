class FlintDirectives {
  String? xShow;
  String? xData;
  String? xInit;
  String? xText;
  String? xHtml;
  String? xModel;
  Map<String, String>? xBind;
  Map<String, String>? xOn;
  String? xFor;
  String? xTransition;
  String? xEffect;
  bool? xIgnore;
  String? xRef;
  bool? xCloak;
  String? xTeleport;
  String? xIf;
  String? xId;

  FlintDirectives({
    this.xShow,
    this.xData,
    this.xInit,
    this.xText,
    this.xHtml,
    this.xModel,
    this.xBind,
    this.xOn,
    this.xFor,
    this.xTransition,
    this.xEffect,
    this.xIgnore,
    this.xRef,
    this.xCloak,
    this.xTeleport,
    this.xIf,
    this.xId,
  });

  Map<String, String> toAttributes() {
    final attrs = <String, String>{};

    void addAttr(String name, String? value) {
      if (value != null) attrs[name] = value;
    }

    addAttr('x-data', xData);
    addAttr('x-init', xInit);
    addAttr('x-show', xShow);
    addAttr('x-text', xText);
    addAttr('x-html', xHtml);
    addAttr('x-model', xModel);
    addAttr('x-for', xFor);
    addAttr('x-transition', xTransition);
    addAttr('x-effect', xEffect);
    addAttr('x-ref', xRef);
    addAttr('x-teleport', xTeleport);
    addAttr('x-if', xIf);
    addAttr('x-id', xId);

    if (xIgnore == true) attrs['x-ignore'] = '';
    if (xCloak == true) attrs['x-cloak'] = '';

    xBind?.forEach((k, v) => attrs['x-bind:$k'] = v);
    xOn?.forEach((e, v) => attrs['x-on:$e'] = v);

    return attrs;
  }

  Map<String, dynamic> toJson() => {
        'xShow': xShow,
        'xData': xData,
        'xInit': xInit,
        'xText': xText,
        'xHtml': xHtml,
        'xModel': xModel,
        'xBind': xBind,
        'xOn': xOn,
        'xFor': xFor,
        'xTransition': xTransition,
        'xEffect': xEffect,
        'xIgnore': xIgnore,
        'xRef': xRef,
        'xCloak': xCloak,
        'xTeleport': xTeleport,
        'xIf': xIf,
        'xId': xId,
      };
}
