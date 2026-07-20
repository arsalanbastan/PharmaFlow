// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Dashboard {

/// نام کاربر
 String get userName;/// نام داروخانه
 String get pharmacyName;/// تاریخ شمسی امروز
 String get todayDate;/// جمع کل تعهدات امروز
 int get totalTodayCommitments;/// وضعیت چک‌های امروز به تفکیک حساب‌های بانکی
 List<TodayCheck> get todayChecks;/// تعهدات مالی آینده
 List<CommitmentPeriod> get commitmentPeriods;
/// Create a copy of Dashboard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardCopyWith<Dashboard> get copyWith => _$DashboardCopyWithImpl<Dashboard>(this as Dashboard, _$identity);

  /// Serializes this Dashboard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Dashboard&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.pharmacyName, pharmacyName) || other.pharmacyName == pharmacyName)&&(identical(other.todayDate, todayDate) || other.todayDate == todayDate)&&(identical(other.totalTodayCommitments, totalTodayCommitments) || other.totalTodayCommitments == totalTodayCommitments)&&const DeepCollectionEquality().equals(other.todayChecks, todayChecks)&&const DeepCollectionEquality().equals(other.commitmentPeriods, commitmentPeriods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userName,pharmacyName,todayDate,totalTodayCommitments,const DeepCollectionEquality().hash(todayChecks),const DeepCollectionEquality().hash(commitmentPeriods));

@override
String toString() {
  return 'Dashboard(userName: $userName, pharmacyName: $pharmacyName, todayDate: $todayDate, totalTodayCommitments: $totalTodayCommitments, todayChecks: $todayChecks, commitmentPeriods: $commitmentPeriods)';
}


}

/// @nodoc
abstract mixin class $DashboardCopyWith<$Res>  {
  factory $DashboardCopyWith(Dashboard value, $Res Function(Dashboard) _then) = _$DashboardCopyWithImpl;
@useResult
$Res call({
 String userName, String pharmacyName, String todayDate, int totalTodayCommitments, List<TodayCheck> todayChecks, List<CommitmentPeriod> commitmentPeriods
});




}
/// @nodoc
class _$DashboardCopyWithImpl<$Res>
    implements $DashboardCopyWith<$Res> {
  _$DashboardCopyWithImpl(this._self, this._then);

  final Dashboard _self;
  final $Res Function(Dashboard) _then;

/// Create a copy of Dashboard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userName = null,Object? pharmacyName = null,Object? todayDate = null,Object? totalTodayCommitments = null,Object? todayChecks = null,Object? commitmentPeriods = null,}) {
  return _then(_self.copyWith(
userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,pharmacyName: null == pharmacyName ? _self.pharmacyName : pharmacyName // ignore: cast_nullable_to_non_nullable
as String,todayDate: null == todayDate ? _self.todayDate : todayDate // ignore: cast_nullable_to_non_nullable
as String,totalTodayCommitments: null == totalTodayCommitments ? _self.totalTodayCommitments : totalTodayCommitments // ignore: cast_nullable_to_non_nullable
as int,todayChecks: null == todayChecks ? _self.todayChecks : todayChecks // ignore: cast_nullable_to_non_nullable
as List<TodayCheck>,commitmentPeriods: null == commitmentPeriods ? _self.commitmentPeriods : commitmentPeriods // ignore: cast_nullable_to_non_nullable
as List<CommitmentPeriod>,
  ));
}

}


/// Adds pattern-matching-related methods to [Dashboard].
extension DashboardPatterns on Dashboard {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Dashboard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Dashboard() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Dashboard value)  $default,){
final _that = this;
switch (_that) {
case _Dashboard():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Dashboard value)?  $default,){
final _that = this;
switch (_that) {
case _Dashboard() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userName,  String pharmacyName,  String todayDate,  int totalTodayCommitments,  List<TodayCheck> todayChecks,  List<CommitmentPeriod> commitmentPeriods)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Dashboard() when $default != null:
return $default(_that.userName,_that.pharmacyName,_that.todayDate,_that.totalTodayCommitments,_that.todayChecks,_that.commitmentPeriods);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userName,  String pharmacyName,  String todayDate,  int totalTodayCommitments,  List<TodayCheck> todayChecks,  List<CommitmentPeriod> commitmentPeriods)  $default,) {final _that = this;
switch (_that) {
case _Dashboard():
return $default(_that.userName,_that.pharmacyName,_that.todayDate,_that.totalTodayCommitments,_that.todayChecks,_that.commitmentPeriods);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userName,  String pharmacyName,  String todayDate,  int totalTodayCommitments,  List<TodayCheck> todayChecks,  List<CommitmentPeriod> commitmentPeriods)?  $default,) {final _that = this;
switch (_that) {
case _Dashboard() when $default != null:
return $default(_that.userName,_that.pharmacyName,_that.todayDate,_that.totalTodayCommitments,_that.todayChecks,_that.commitmentPeriods);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Dashboard implements Dashboard {
  const _Dashboard({required this.userName, required this.pharmacyName, required this.todayDate, required this.totalTodayCommitments, final  List<TodayCheck> todayChecks = const <TodayCheck>[], final  List<CommitmentPeriod> commitmentPeriods = const <CommitmentPeriod>[]}): _todayChecks = todayChecks,_commitmentPeriods = commitmentPeriods;
  factory _Dashboard.fromJson(Map<String, dynamic> json) => _$DashboardFromJson(json);

/// نام کاربر
@override final  String userName;
/// نام داروخانه
@override final  String pharmacyName;
/// تاریخ شمسی امروز
@override final  String todayDate;
/// جمع کل تعهدات امروز
@override final  int totalTodayCommitments;
/// وضعیت چک‌های امروز به تفکیک حساب‌های بانکی
 final  List<TodayCheck> _todayChecks;
/// وضعیت چک‌های امروز به تفکیک حساب‌های بانکی
@override@JsonKey() List<TodayCheck> get todayChecks {
  if (_todayChecks is EqualUnmodifiableListView) return _todayChecks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_todayChecks);
}

/// تعهدات مالی آینده
 final  List<CommitmentPeriod> _commitmentPeriods;
/// تعهدات مالی آینده
@override@JsonKey() List<CommitmentPeriod> get commitmentPeriods {
  if (_commitmentPeriods is EqualUnmodifiableListView) return _commitmentPeriods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commitmentPeriods);
}


/// Create a copy of Dashboard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardCopyWith<_Dashboard> get copyWith => __$DashboardCopyWithImpl<_Dashboard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashboardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Dashboard&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.pharmacyName, pharmacyName) || other.pharmacyName == pharmacyName)&&(identical(other.todayDate, todayDate) || other.todayDate == todayDate)&&(identical(other.totalTodayCommitments, totalTodayCommitments) || other.totalTodayCommitments == totalTodayCommitments)&&const DeepCollectionEquality().equals(other._todayChecks, _todayChecks)&&const DeepCollectionEquality().equals(other._commitmentPeriods, _commitmentPeriods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userName,pharmacyName,todayDate,totalTodayCommitments,const DeepCollectionEquality().hash(_todayChecks),const DeepCollectionEquality().hash(_commitmentPeriods));

@override
String toString() {
  return 'Dashboard(userName: $userName, pharmacyName: $pharmacyName, todayDate: $todayDate, totalTodayCommitments: $totalTodayCommitments, todayChecks: $todayChecks, commitmentPeriods: $commitmentPeriods)';
}


}

/// @nodoc
abstract mixin class _$DashboardCopyWith<$Res> implements $DashboardCopyWith<$Res> {
  factory _$DashboardCopyWith(_Dashboard value, $Res Function(_Dashboard) _then) = __$DashboardCopyWithImpl;
@override @useResult
$Res call({
 String userName, String pharmacyName, String todayDate, int totalTodayCommitments, List<TodayCheck> todayChecks, List<CommitmentPeriod> commitmentPeriods
});




}
/// @nodoc
class __$DashboardCopyWithImpl<$Res>
    implements _$DashboardCopyWith<$Res> {
  __$DashboardCopyWithImpl(this._self, this._then);

  final _Dashboard _self;
  final $Res Function(_Dashboard) _then;

/// Create a copy of Dashboard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userName = null,Object? pharmacyName = null,Object? todayDate = null,Object? totalTodayCommitments = null,Object? todayChecks = null,Object? commitmentPeriods = null,}) {
  return _then(_Dashboard(
userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,pharmacyName: null == pharmacyName ? _self.pharmacyName : pharmacyName // ignore: cast_nullable_to_non_nullable
as String,todayDate: null == todayDate ? _self.todayDate : todayDate // ignore: cast_nullable_to_non_nullable
as String,totalTodayCommitments: null == totalTodayCommitments ? _self.totalTodayCommitments : totalTodayCommitments // ignore: cast_nullable_to_non_nullable
as int,todayChecks: null == todayChecks ? _self._todayChecks : todayChecks // ignore: cast_nullable_to_non_nullable
as List<TodayCheck>,commitmentPeriods: null == commitmentPeriods ? _self._commitmentPeriods : commitmentPeriods // ignore: cast_nullable_to_non_nullable
as List<CommitmentPeriod>,
  ));
}


}

// dart format on
