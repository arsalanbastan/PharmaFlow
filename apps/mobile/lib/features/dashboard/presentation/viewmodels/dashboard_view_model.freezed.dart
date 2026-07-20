// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DashboardViewModel {

 DashboardHeaderViewModel get header; CheckStatusViewModel get checkStatus; FinancialCommitmentsViewModel get financialCommitments;
/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardViewModelCopyWith<DashboardViewModel> get copyWith => _$DashboardViewModelCopyWithImpl<DashboardViewModel>(this as DashboardViewModel, _$identity);

  /// Serializes this DashboardViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardViewModel&&(identical(other.header, header) || other.header == header)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus)&&(identical(other.financialCommitments, financialCommitments) || other.financialCommitments == financialCommitments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,checkStatus,financialCommitments);

@override
String toString() {
  return 'DashboardViewModel(header: $header, checkStatus: $checkStatus, financialCommitments: $financialCommitments)';
}


}

/// @nodoc
abstract mixin class $DashboardViewModelCopyWith<$Res>  {
  factory $DashboardViewModelCopyWith(DashboardViewModel value, $Res Function(DashboardViewModel) _then) = _$DashboardViewModelCopyWithImpl;
@useResult
$Res call({
 DashboardHeaderViewModel header, CheckStatusViewModel checkStatus, FinancialCommitmentsViewModel financialCommitments
});


$DashboardHeaderViewModelCopyWith<$Res> get header;$CheckStatusViewModelCopyWith<$Res> get checkStatus;$FinancialCommitmentsViewModelCopyWith<$Res> get financialCommitments;

}
/// @nodoc
class _$DashboardViewModelCopyWithImpl<$Res>
    implements $DashboardViewModelCopyWith<$Res> {
  _$DashboardViewModelCopyWithImpl(this._self, this._then);

  final DashboardViewModel _self;
  final $Res Function(DashboardViewModel) _then;

/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? header = null,Object? checkStatus = null,Object? financialCommitments = null,}) {
  return _then(_self.copyWith(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as DashboardHeaderViewModel,checkStatus: null == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as CheckStatusViewModel,financialCommitments: null == financialCommitments ? _self.financialCommitments : financialCommitments // ignore: cast_nullable_to_non_nullable
as FinancialCommitmentsViewModel,
  ));
}
/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DashboardHeaderViewModelCopyWith<$Res> get header {
  
  return $DashboardHeaderViewModelCopyWith<$Res>(_self.header, (value) {
    return _then(_self.copyWith(header: value));
  });
}/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckStatusViewModelCopyWith<$Res> get checkStatus {
  
  return $CheckStatusViewModelCopyWith<$Res>(_self.checkStatus, (value) {
    return _then(_self.copyWith(checkStatus: value));
  });
}/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinancialCommitmentsViewModelCopyWith<$Res> get financialCommitments {
  
  return $FinancialCommitmentsViewModelCopyWith<$Res>(_self.financialCommitments, (value) {
    return _then(_self.copyWith(financialCommitments: value));
  });
}
}


/// Adds pattern-matching-related methods to [DashboardViewModel].
extension DashboardViewModelPatterns on DashboardViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardViewModel value)  $default,){
final _that = this;
switch (_that) {
case _DashboardViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DashboardHeaderViewModel header,  CheckStatusViewModel checkStatus,  FinancialCommitmentsViewModel financialCommitments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardViewModel() when $default != null:
return $default(_that.header,_that.checkStatus,_that.financialCommitments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DashboardHeaderViewModel header,  CheckStatusViewModel checkStatus,  FinancialCommitmentsViewModel financialCommitments)  $default,) {final _that = this;
switch (_that) {
case _DashboardViewModel():
return $default(_that.header,_that.checkStatus,_that.financialCommitments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DashboardHeaderViewModel header,  CheckStatusViewModel checkStatus,  FinancialCommitmentsViewModel financialCommitments)?  $default,) {final _that = this;
switch (_that) {
case _DashboardViewModel() when $default != null:
return $default(_that.header,_that.checkStatus,_that.financialCommitments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DashboardViewModel implements DashboardViewModel {
  const _DashboardViewModel({required this.header, required this.checkStatus, required this.financialCommitments});
  factory _DashboardViewModel.fromJson(Map<String, dynamic> json) => _$DashboardViewModelFromJson(json);

@override final  DashboardHeaderViewModel header;
@override final  CheckStatusViewModel checkStatus;
@override final  FinancialCommitmentsViewModel financialCommitments;

/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardViewModelCopyWith<_DashboardViewModel> get copyWith => __$DashboardViewModelCopyWithImpl<_DashboardViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashboardViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardViewModel&&(identical(other.header, header) || other.header == header)&&(identical(other.checkStatus, checkStatus) || other.checkStatus == checkStatus)&&(identical(other.financialCommitments, financialCommitments) || other.financialCommitments == financialCommitments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,checkStatus,financialCommitments);

@override
String toString() {
  return 'DashboardViewModel(header: $header, checkStatus: $checkStatus, financialCommitments: $financialCommitments)';
}


}

/// @nodoc
abstract mixin class _$DashboardViewModelCopyWith<$Res> implements $DashboardViewModelCopyWith<$Res> {
  factory _$DashboardViewModelCopyWith(_DashboardViewModel value, $Res Function(_DashboardViewModel) _then) = __$DashboardViewModelCopyWithImpl;
@override @useResult
$Res call({
 DashboardHeaderViewModel header, CheckStatusViewModel checkStatus, FinancialCommitmentsViewModel financialCommitments
});


@override $DashboardHeaderViewModelCopyWith<$Res> get header;@override $CheckStatusViewModelCopyWith<$Res> get checkStatus;@override $FinancialCommitmentsViewModelCopyWith<$Res> get financialCommitments;

}
/// @nodoc
class __$DashboardViewModelCopyWithImpl<$Res>
    implements _$DashboardViewModelCopyWith<$Res> {
  __$DashboardViewModelCopyWithImpl(this._self, this._then);

  final _DashboardViewModel _self;
  final $Res Function(_DashboardViewModel) _then;

/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? header = null,Object? checkStatus = null,Object? financialCommitments = null,}) {
  return _then(_DashboardViewModel(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as DashboardHeaderViewModel,checkStatus: null == checkStatus ? _self.checkStatus : checkStatus // ignore: cast_nullable_to_non_nullable
as CheckStatusViewModel,financialCommitments: null == financialCommitments ? _self.financialCommitments : financialCommitments // ignore: cast_nullable_to_non_nullable
as FinancialCommitmentsViewModel,
  ));
}

/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DashboardHeaderViewModelCopyWith<$Res> get header {
  
  return $DashboardHeaderViewModelCopyWith<$Res>(_self.header, (value) {
    return _then(_self.copyWith(header: value));
  });
}/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CheckStatusViewModelCopyWith<$Res> get checkStatus {
  
  return $CheckStatusViewModelCopyWith<$Res>(_self.checkStatus, (value) {
    return _then(_self.copyWith(checkStatus: value));
  });
}/// Create a copy of DashboardViewModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FinancialCommitmentsViewModelCopyWith<$Res> get financialCommitments {
  
  return $FinancialCommitmentsViewModelCopyWith<$Res>(_self.financialCommitments, (value) {
    return _then(_self.copyWith(financialCommitments: value));
  });
}
}

// dart format on
