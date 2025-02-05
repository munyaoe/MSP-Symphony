import { Store } from '@ngrx/store';
import { Router } from '@angular/router';
import { Injectable } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { of } from 'rxjs';
import { mergeMap, map, catchError, tap, concatMap, withLatestFrom } from 'rxjs/operators';
import { State } from '@src/app/app-reducer';
import UserService from './user.service';
import { UserActions } from './';
import { AreaActions } from '@data/area';
import { MetadataActions } from '@data/metadata';
import { CalculationActions } from '@data/calculation';
import { LegendType } from '@data/calculation/calculation.interfaces';

const legendTypes: LegendType[] = ['result', 'ecosystem', 'pressure'];

@Injectable()
export class UserEffects {
  constructor(
    private actions$: Actions,
    private store$: Store<State>,
    private userService: UserService,
    private router: Router
  ) {}

  loginUser$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.loginUser),
    withLatestFrom(this.store$),
    mergeMap(([{ username, password }, state]) =>
      this.userService.login(username, password).pipe(
        map(user => [
          UserActions.loginUserSuccess({ user }),
          UserActions.navigateTo({ url: state.user.redirectUrl })
        ]),
        concatMap(actions => actions),
        catchError(error =>
          of(
            UserActions.loginUserFailure({
              error: {
                status: error.status,
                message: error.error.errorMessage
              }
            })
          )
        )
      )
    )
  ));

  logoutUser$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.logoutUser),
    mergeMap(() =>
      this.userService.logout().pipe(
        map(() => UserActions.logoutUserSuccess()),
        catchError(error =>
          of(
            UserActions.logoutUserFailure({
              error: {
                status: error.status,
                message: error.error
              }
            })
          )
        )
      )
    )
  ));

  logoutUserSuccess$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.logoutUserSuccess),
    map(() => UserActions.navigateTo({ url: '/login' }))
  ));

  fetchUser$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.fetchUser),
    mergeMap(() =>
      this.userService.fetchUser().pipe(
        map(user => UserActions.fetchUserSuccess({ user })),
        catchError(error =>
          of(
            UserActions.fetchUserFailure({
              error: {
                status: error.status,
                message: error.error
              }
            })
          )
        )
      )
    )
  ));

  fetchUserFailure$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.fetchUserFailure),
    map(() => UserActions.navigateTo({ url: '/login' }))
  ));

  navigateTo$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.navigateTo),
    tap(({ url }) => this.router.navigateByUrl(url))
  ), { dispatch: false });

  userIsLoggedIn$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.fetchUserSuccess, UserActions.loginUserSuccess),
    concatMap(() => [
      AreaActions.fetchNationalAreas(),
      AreaActions.fetchUserDefinedAreas(),
      AreaActions.fetchBoundaries(),
      UserActions.fetchBaseline(),
      ...legendTypes.map(legendType => CalculationActions.fetchLegend({ legendType }))
    ])
  ));

  baselineIsFetched$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.fetchBaseline),
    mergeMap(() =>
      this.userService.fetchBaseline().pipe(
        map(baseline => UserActions.fetchBaselineSuccess({ baseline: baseline })),
        catchError(error =>
          of(
            UserActions.fetchBaselineFailure({
              error: {
                status: error.status,
                message: error.error
              }
            })
          )
        )
      )
    )
  ));

  fetchedMetadata$ = createEffect(() => this.actions$.pipe(
    ofType(UserActions.fetchBaselineSuccess),
    map(props => MetadataActions.fetchMetadataForBaseline({ baselineName: props.baseline.name }))
  ));
}
