// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'financial_commitments_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FinancialCommitmentsViewModel {

 List<CommitmentPeriodViewModel> get periods;
/// Create a copy of FinancialCommitmentsViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FinancialCommitmentsViewModelCopyWith<FinancialCommitmentsViewModel> get copyWith => _$FinancialCommitmentsViewModelCopyWithImpl<FinancialCommitmentsViewModel>(this as FinancialCommitmentsViewModel, _$identity);

  /// Serializes this FinancialCommitmentsViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FinancialCommitmentsViewModel&&const DeepCollectionEquality().equals(other.periods, periods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(periods));

@override
String toString() {
  return 'FinancialCommitmentsViewModel(periods: $periods)';
}


}

/// @nodoc
abstract mixin class $FinancialCommitmentsViewModelCopyWith<$Res>  {
  factory $FinancialCommitmentsViewModelCopyWith(FinancialCommitmentsViewModel value, $Res Function(FinancialCommitmentsViewModel) _then) = _$FinancialCommitmentsViewModelCopyWithImpl;
@useResult
$Res call({
 List<CommitmentPeriodViewModel> periods
});




}
/// @nodoc
class _$FinancialCommitmentsViewModelCopyWithImpl<$Res>
    implements $FinancialCommitmentsViewModelCopyWith<$Res> {
  _$FinancialCommitmentsViewModelCopyWithImpl(this._self, this._then);

  final FinancialCommitmentsViewModel _self;
  final $Res Function(FinancialCommitmentsViewModel) _then;

/// Create a copy of FinancialCommitmentsViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? periods = null,}) {
  return _then(_self.copyWith(
periods: null == periods ? _self.periods : periods // ignore: cast_nullable_to_non_nullable
as List<CommitmentPeriodViewModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [FinancialCommitmentsViewModel].
extension FinancialCommitmentsViewModelPatterns on FinancialCommitmentsViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FinancialCommitmentsViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FinancialCommitmentsViewModel value)  $default,){
final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FinancialCommitmentsViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CommitmentPeriodViewModel> periods)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel() when $default != null:
return $default(_that.periods);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CommitmentPeriodViewModel> periods)  $default,) {final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel():
return $default(_that.periods);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CommitmentPeriodViewModel> periods)?  $default,) {final _that = this;
switch (_that) {
case _FinancialCommitmentsViewModel() when $default != null:
return $default(_that.periods);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FinancialCommitmentsViewModel implements FinancialCommitmentsViewModel {
  const _FinancialCommitmentsViewModel({required final  List<CommitmentPeriodViewModel> periods}): _periods = periods;
  factory _FinancialCommitmentsViewModel.fromJson(Map<String, dynamic> json) => _$FinancialCommitmentsViewModelFromJson(json);

 final  List<CommitmentPeriodViewModel> _periods;
@override List<CommitmentPeriodViewModel> get periods {
  if (_periods is EqualUnmodifiableListView) return _periods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_periods);
}


/// Create a copy of FinancialCommitmentsViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FinancialCommitmentsViewModelCopyWith<_FinancialCommitmentsViewModel> get copyWith => __$FinancialCommitmentsViewModelCopyWithImpl<_FinancialCommitmentsViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FinancialCommitmentsViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FinancialCommitmentsViewModel&&const DeepCollectionEquality().equals(other._periods, _periods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_periods));

@override
String toString() {
  return 'FinancialCommitmentsViewModel(periods: $periods)';
}


}

/// @nodoc
abstract mixin class _$FinancialCommitmentsViewModelCopyWith<$Res> implements $FinancialCommitmentsViewModelCopyWith<$Res> {
  factory _$FinancialCommitmentsViewModelCopyWith(_FinancialCommitmentsViewModel value, $Res Function(_FinancialCommitmentsViewModel) _then) = __$FinancialCommitmentsViewModelCopyWithImpl;
@override @useResult
$Res call({
 List<CommitmentPeriodViewModel> periods
});




}
/// @nodoc
class __$FinancialCommitmentsViewModelCopyWithImpl<$Res>
    implements _$FinancialCommitmentsViewModelCopyWith<$Res> {
  __$FinancialCommitmentsViewModelCopyWithImpl(this._self, this._then);

  final _FinancialCommitmentsViewModel _self;
  final $Res Function(_FinancialCommitmentsViewModel) _then;

/// Create a copy of FinancialCommitmentsViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? periods = null,}) {
  return _then(_FinancialCommitmentsViewModel(
periods: null == periods ? _self._periods : periods // ignore: cast_nullable_to_non_nullable
as List<CommitmentPeriodViewModel>,
  ));
}


}


/// @nodoc
mixin _$CommitmentPeriodViewModel {

 String get title; String get fromDate; String get toDate; int get totalAmount; int get chequeCount; List<BankCommitmentViewModel> get banks;
/// Create a copy of CommitmentPeriodViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitmentPeriodViewModelCopyWith<CommitmentPeriodViewModel> get copyWith => _$CommitmentPeriodViewModelCopyWithImpl<CommitmentPeriodViewModel>(this as CommitmentPeriodViewModel, _$identity);

  /// Serializes this CommitmentPeriodViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitmentPeriodViewModel&&(identical(other.title, title) || other.title == title)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.toDate, toDate) || other.toDate == toDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other.banks, banks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,fromDate,toDate,totalAmount,chequeCount,const DeepCollectionEquality().hash(banks));

@override
String toString() {
  return 'CommitmentPeriodViewModel(title: $title, fromDate: $fromDate, toDate: $toDate, totalAmount: $totalAmount, chequeCount: $chequeCount, banks: $banks)';
}


}

/// @nodoc
abstract mixin class $CommitmentPeriodViewModelCopyWith<$Res>  {
  factory $CommitmentPeriodViewModelCopyWith(CommitmentPeriodViewModel value, $Res Function(CommitmentPeriodViewModel) _then) = _$CommitmentPeriodViewModelCopyWithImpl;
@useResult
$Res call({
 String title, String fromDate, String toDate, int totalAmount, int chequeCount, List<BankCommitmentViewModel> banks
});




}
/// @nodoc
class _$CommitmentPeriodViewModelCopyWithImpl<$Res>
    implements $CommitmentPeriodViewModelCopyWith<$Res> {
  _$CommitmentPeriodViewModelCopyWithImpl(this._self, this._then);

  final CommitmentPeriodViewModel _self;
  final $Res Function(CommitmentPeriodViewModel) _then;

/// Create a copy of CommitmentPeriodViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? fromDate = null,Object? toDate = null,Object? totalAmount = null,Object? chequeCount = null,Object? banks = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,toDate: null == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,banks: null == banks ? _self.banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankCommitmentViewModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommitmentPeriodViewModel].
extension CommitmentPeriodViewModelPatterns on CommitmentPeriodViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitmentPeriodViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitmentPeriodViewModel value)  $default,){
final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitmentPeriodViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitmentViewModel> banks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel() when $default != null:
return $default(_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitmentViewModel> banks)  $default,) {final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel():
return $default(_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitmentViewModel> banks)?  $default,) {final _that = this;
switch (_that) {
case _CommitmentPeriodViewModel() when $default != null:
return $default(_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommitmentPeriodViewModel implements CommitmentPeriodViewModel {
  const _CommitmentPeriodViewModel({required this.title, required this.fromDate, required this.toDate, required this.totalAmount, required this.chequeCount, required final  List<BankCommitmentViewModel> banks}): _banks = banks;
  factory _CommitmentPeriodViewModel.fromJson(Map<String, dynamic> json) => _$CommitmentPeriodViewModelFromJson(json);

@override final  String title;
@override final  String fromDate;
@override final  String toDate;
@override final  int totalAmount;
@override final  int chequeCount;
 final  List<BankCommitmentViewModel> _banks;
@override List<BankCommitmentViewModel> get banks {
  if (_banks is EqualUnmodifiableListView) return _banks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_banks);
}


/// Create a copy of CommitmentPeriodViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitmentPeriodViewModelCopyWith<_CommitmentPeriodViewModel> get copyWith => __$CommitmentPeriodViewModelCopyWithImpl<_CommitmentPeriodViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommitmentPeriodViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitmentPeriodViewModel&&(identical(other.title, title) || other.title == title)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.toDate, toDate) || other.toDate == toDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other._banks, _banks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,fromDate,toDate,totalAmount,chequeCount,const DeepCollectionEquality().hash(_banks));

@override
String toString() {
  return 'CommitmentPeriodViewModel(title: $title, fromDate: $fromDate, toDate: $toDate, totalAmount: $totalAmount, chequeCount: $chequeCount, banks: $banks)';
}


}

/// @nodoc
abstract mixin class _$CommitmentPeriodViewModelCopyWith<$Res> implements $CommitmentPeriodViewModelCopyWith<$Res> {
  factory _$CommitmentPeriodViewModelCopyWith(_CommitmentPeriodViewModel value, $Res Function(_CommitmentPeriodViewModel) _then) = __$CommitmentPeriodViewModelCopyWithImpl;
@override @useResult
$Res call({
 String title, String fromDate, String toDate, int totalAmount, int chequeCount, List<BankCommitmentViewModel> banks
});




}
/// @nodoc
class __$CommitmentPeriodViewModelCopyWithImpl<$Res>
    implements _$CommitmentPeriodViewModelCopyWith<$Res> {
  __$CommitmentPeriodViewModelCopyWithImpl(this._self, this._then);

  final _CommitmentPeriodViewModel _self;
  final $Res Function(_CommitmentPeriodViewModel) _then;

/// Create a copy of CommitmentPeriodViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? fromDate = null,Object? toDate = null,Object? totalAmount = null,Object? chequeCount = null,Object? banks = null,}) {
  return _then(_CommitmentPeriodViewModel(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,toDate: null == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,banks: null == banks ? _self._banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankCommitmentViewModel>,
  ));
}


}


/// @nodoc
mixin _$BankCommitmentViewModel {

 String get bankName; int get totalAmount; int get chequeCount; List<CompanyCommitmentViewModel> get companies;
/// Create a copy of BankCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankCommitmentViewModelCopyWith<BankCommitmentViewModel> get copyWith => _$BankCommitmentViewModelCopyWithImpl<BankCommitmentViewModel>(this as BankCommitmentViewModel, _$identity);

  /// Serializes this BankCommitmentViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankCommitmentViewModel&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other.companies, companies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankName,totalAmount,chequeCount,const DeepCollectionEquality().hash(companies));

@override
String toString() {
  return 'BankCommitmentViewModel(bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount, companies: $companies)';
}


}

/// @nodoc
abstract mixin class $BankCommitmentViewModelCopyWith<$Res>  {
  factory $BankCommitmentViewModelCopyWith(BankCommitmentViewModel value, $Res Function(BankCommitmentViewModel) _then) = _$BankCommitmentViewModelCopyWithImpl;
@useResult
$Res call({
 String bankName, int totalAmount, int chequeCount, List<CompanyCommitmentViewModel> companies
});




}
/// @nodoc
class _$BankCommitmentViewModelCopyWithImpl<$Res>
    implements $BankCommitmentViewModelCopyWith<$Res> {
  _$BankCommitmentViewModelCopyWithImpl(this._self, this._then);

  final BankCommitmentViewModel _self;
  final $Res Function(BankCommitmentViewModel) _then;

/// Create a copy of BankCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,Object? companies = null,}) {
  return _then(_self.copyWith(
bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,companies: null == companies ? _self.companies : companies // ignore: cast_nullable_to_non_nullable
as List<CompanyCommitmentViewModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [BankCommitmentViewModel].
extension BankCommitmentViewModelPatterns on BankCommitmentViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankCommitmentViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankCommitmentViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankCommitmentViewModel value)  $default,){
final _that = this;
switch (_that) {
case _BankCommitmentViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankCommitmentViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _BankCommitmentViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitmentViewModel> companies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankCommitmentViewModel() when $default != null:
return $default(_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitmentViewModel> companies)  $default,) {final _that = this;
switch (_that) {
case _BankCommitmentViewModel():
return $default(_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitmentViewModel> companies)?  $default,) {final _that = this;
switch (_that) {
case _BankCommitmentViewModel() when $default != null:
return $default(_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankCommitmentViewModel implements BankCommitmentViewModel {
  const _BankCommitmentViewModel({required this.bankName, required this.totalAmount, required this.chequeCount, required final  List<CompanyCommitmentViewModel> companies}): _companies = companies;
  factory _BankCommitmentViewModel.fromJson(Map<String, dynamic> json) => _$BankCommitmentViewModelFromJson(json);

@override final  String bankName;
@override final  int totalAmount;
@override final  int chequeCount;
 final  List<CompanyCommitmentViewModel> _companies;
@override List<CompanyCommitmentViewModel> get companies {
  if (_companies is EqualUnmodifiableListView) return _companies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_companies);
}


/// Create a copy of BankCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankCommitmentViewModelCopyWith<_BankCommitmentViewModel> get copyWith => __$BankCommitmentViewModelCopyWithImpl<_BankCommitmentViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankCommitmentViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankCommitmentViewModel&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other._companies, _companies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankName,totalAmount,chequeCount,const DeepCollectionEquality().hash(_companies));

@override
String toString() {
  return 'BankCommitmentViewModel(bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount, companies: $companies)';
}


}

/// @nodoc
abstract mixin class _$BankCommitmentViewModelCopyWith<$Res> implements $BankCommitmentViewModelCopyWith<$Res> {
  factory _$BankCommitmentViewModelCopyWith(_BankCommitmentViewModel value, $Res Function(_BankCommitmentViewModel) _then) = __$BankCommitmentViewModelCopyWithImpl;
@override @useResult
$Res call({
 String bankName, int totalAmount, int chequeCount, List<CompanyCommitmentViewModel> companies
});




}
/// @nodoc
class __$BankCommitmentViewModelCopyWithImpl<$Res>
    implements _$BankCommitmentViewModelCopyWith<$Res> {
  __$BankCommitmentViewModelCopyWithImpl(this._self, this._then);

  final _BankCommitmentViewModel _self;
  final $Res Function(_BankCommitmentViewModel) _then;

/// Create a copy of BankCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,Object? companies = null,}) {
  return _then(_BankCommitmentViewModel(
bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,companies: null == companies ? _self._companies : companies // ignore: cast_nullable_to_non_nullable
as List<CompanyCommitmentViewModel>,
  ));
}


}


/// @nodoc
mixin _$CompanyCommitmentViewModel {

 String get companyName; int get totalAmount; int get chequeCount;
/// Create a copy of CompanyCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCommitmentViewModelCopyWith<CompanyCommitmentViewModel> get copyWith => _$CompanyCommitmentViewModelCopyWithImpl<CompanyCommitmentViewModel>(this as CompanyCommitmentViewModel, _$identity);

  /// Serializes this CompanyCommitmentViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyCommitmentViewModel&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,companyName,totalAmount,chequeCount);

@override
String toString() {
  return 'CompanyCommitmentViewModel(companyName: $companyName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class $CompanyCommitmentViewModelCopyWith<$Res>  {
  factory $CompanyCommitmentViewModelCopyWith(CompanyCommitmentViewModel value, $Res Function(CompanyCommitmentViewModel) _then) = _$CompanyCommitmentViewModelCopyWithImpl;
@useResult
$Res call({
 String companyName, int totalAmount, int chequeCount
});




}
/// @nodoc
class _$CompanyCommitmentViewModelCopyWithImpl<$Res>
    implements $CompanyCommitmentViewModelCopyWith<$Res> {
  _$CompanyCommitmentViewModelCopyWithImpl(this._self, this._then);

  final CompanyCommitmentViewModel _self;
  final $Res Function(CompanyCommitmentViewModel) _then;

/// Create a copy of CompanyCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? companyName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_self.copyWith(
companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyCommitmentViewModel].
extension CompanyCommitmentViewModelPatterns on CompanyCommitmentViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyCommitmentViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyCommitmentViewModel value)  $default,){
final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyCommitmentViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String companyName,  int totalAmount,  int chequeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel() when $default != null:
return $default(_that.companyName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String companyName,  int totalAmount,  int chequeCount)  $default,) {final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel():
return $default(_that.companyName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String companyName,  int totalAmount,  int chequeCount)?  $default,) {final _that = this;
switch (_that) {
case _CompanyCommitmentViewModel() when $default != null:
return $default(_that.companyName,_that.totalAmount,_that.chequeCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyCommitmentViewModel implements CompanyCommitmentViewModel {
  const _CompanyCommitmentViewModel({required this.companyName, required this.totalAmount, required this.chequeCount});
  factory _CompanyCommitmentViewModel.fromJson(Map<String, dynamic> json) => _$CompanyCommitmentViewModelFromJson(json);

@override final  String companyName;
@override final  int totalAmount;
@override final  int chequeCount;

/// Create a copy of CompanyCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCommitmentViewModelCopyWith<_CompanyCommitmentViewModel> get copyWith => __$CompanyCommitmentViewModelCopyWithImpl<_CompanyCommitmentViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyCommitmentViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyCommitmentViewModel&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,companyName,totalAmount,chequeCount);

@override
String toString() {
  return 'CompanyCommitmentViewModel(companyName: $companyName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class _$CompanyCommitmentViewModelCopyWith<$Res> implements $CompanyCommitmentViewModelCopyWith<$Res> {
  factory _$CompanyCommitmentViewModelCopyWith(_CompanyCommitmentViewModel value, $Res Function(_CompanyCommitmentViewModel) _then) = __$CompanyCommitmentViewModelCopyWithImpl;
@override @useResult
$Res call({
 String companyName, int totalAmount, int chequeCount
});




}
/// @nodoc
class __$CompanyCommitmentViewModelCopyWithImpl<$Res>
    implements _$CompanyCommitmentViewModelCopyWith<$Res> {
  __$CompanyCommitmentViewModelCopyWithImpl(this._self, this._then);

  final _CompanyCommitmentViewModel _self;
  final $Res Function(_CompanyCommitmentViewModel) _then;

/// Create a copy of CompanyCommitmentViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? companyName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_CompanyCommitmentViewModel(
companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
