// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_header_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DashboardHeaderViewModel {

 String get userName; String get pharmacyName; String get todayDate;
/// Create a copy of DashboardHeaderViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardHeaderViewModelCopyWith<DashboardHeaderViewModel> get copyWith => _$DashboardHeaderViewModelCopyWithImpl<DashboardHeaderViewModel>(this as DashboardHeaderViewModel, _$identity);

  /// Serializes this DashboardHeaderViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardHeaderViewModel&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.pharmacyName, pharmacyName) || other.pharmacyName == pharmacyName)&&(identical(other.todayDate, todayDate) || other.todayDate == todayDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userName,pharmacyName,todayDate);

@override
String toString() {
  return 'DashboardHeaderViewModel(userName: $userName, pharmacyName: $pharmacyName, todayDate: $todayDate)';
}


}

/// @nodoc
abstract mixin class $DashboardHeaderViewModelCopyWith<$Res>  {
  factory $DashboardHeaderViewModelCopyWith(DashboardHeaderViewModel value, $Res Function(DashboardHeaderViewModel) _then) = _$DashboardHeaderViewModelCopyWithImpl;
@useResult
$Res call({
 String userName, String pharmacyName, String todayDate
});




}
/// @nodoc
class _$DashboardHeaderViewModelCopyWithImpl<$Res>
    implements $DashboardHeaderViewModelCopyWith<$Res> {
  _$DashboardHeaderViewModelCopyWithImpl(this._self, this._then);

  final DashboardHeaderViewModel _self;
  final $Res Function(DashboardHeaderViewModel) _then;

/// Create a copy of DashboardHeaderViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userName = null,Object? pharmacyName = null,Object? todayDate = null,}) {
  return _then(_self.copyWith(
userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,pharmacyName: null == pharmacyName ? _self.pharmacyName : pharmacyName // ignore: cast_nullable_to_non_nullable
as String,todayDate: null == todayDate ? _self.todayDate : todayDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardHeaderViewModel].
extension DashboardHeaderViewModelPatterns on DashboardHeaderViewModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardHeaderViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardHeaderViewModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardHeaderViewModel value)  $default,){
final _that = this;
switch (_that) {
case _DashboardHeaderViewModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardHeaderViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardHeaderViewModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userName,  String pharmacyName,  String todayDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardHeaderViewModel() when $default != null:
return $default(_that.userName,_that.pharmacyName,_that.todayDate);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userName,  String pharmacyName,  String todayDate)  $default,) {final _that = this;
switch (_that) {
case _DashboardHeaderViewModel():
return $default(_that.userName,_that.pharmacyName,_that.todayDate);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userName,  String pharmacyName,  String todayDate)?  $default,) {final _that = this;
switch (_that) {
case _DashboardHeaderViewModel() when $default != null:
return $default(_that.userName,_that.pharmacyName,_that.todayDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DashboardHeaderViewModel implements DashboardHeaderViewModel {
  const _DashboardHeaderViewModel({required this.userName, required this.pharmacyName, required this.todayDate});
  factory _DashboardHeaderViewModel.fromJson(Map<String, dynamic> json) => _$DashboardHeaderViewModelFromJson(json);

@override final  String userName;
@override final  String pharmacyName;
@override final  String todayDate;

/// Create a copy of DashboardHeaderViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardHeaderViewModelCopyWith<_DashboardHeaderViewModel> get copyWith => __$DashboardHeaderViewModelCopyWithImpl<_DashboardHeaderViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashboardHeaderViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardHeaderViewModel&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.pharmacyName, pharmacyName) || other.pharmacyName == pharmacyName)&&(identical(other.todayDate, todayDate) || other.todayDate == todayDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userName,pharmacyName,todayDate);

@override
String toString() {
  return 'DashboardHeaderViewModel(userName: $userName, pharmacyName: $pharmacyName, todayDate: $todayDate)';
}


}

/// @nodoc
abstract mixin class _$DashboardHeaderViewModelCopyWith<$Res> implements $DashboardHeaderViewModelCopyWith<$Res> {
  factory _$DashboardHeaderViewModelCopyWith(_DashboardHeaderViewModel value, $Res Function(_DashboardHeaderViewModel) _then) = __$DashboardHeaderViewModelCopyWithImpl;
@override @useResult
$Res call({
 String userName, String pharmacyName, String todayDate
});




}
/// @nodoc
class __$DashboardHeaderViewModelCopyWithImpl<$Res>
    implements _$DashboardHeaderViewModelCopyWith<$Res> {
  __$DashboardHeaderViewModelCopyWithImpl(this._self, this._then);

  final _DashboardHeaderViewModel _self;
  final $Res Function(_DashboardHeaderViewModel) _then;

/// Create a copy of DashboardHeaderViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userName = null,Object? pharmacyName = null,Object? todayDate = null,}) {
  return _then(_DashboardHeaderViewModel(
userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,pharmacyName: null == pharmacyName ? _self.pharmacyName : pharmacyName // ignore: cast_nullable_to_non_nullable
as String,todayDate: null == todayDate ? _self.todayDate : todayDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
