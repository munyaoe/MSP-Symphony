import { createReducer, on } from '@ngrx/store';
import { AreaActions, AreaInterfaces } from './';
import { getIn, setIn, updateIn } from 'immutable';
import { ScenarioActions } from '@data/scenario';
import { MatrixRef } from "@src/app/map-view/scenario/scenario-area-detail/matrix-selection/matrix.interfaces";

export const initialState: AreaInterfaces.State = {
  areaTypes: [],
  area: {},
  userArea: {},
  boundaries: [],
  currentSelection: undefined,
  selectionOverlap: false,
  calibratedCalculationAreas: [],
};

export const areaReducer = createReducer(
  initialState,
  on(AreaActions.fetchNationalAreaTypesSuccess, (state, { areaTypes }) => ({
    ...state,
    areaTypes
  })),
  on(AreaActions.fetchNationalAreaSuccess, (state, { nationalArea }) => ({
    ...state,
    area: {
      ...state.area,
      ...nationalArea
    }
  })),
  on(AreaActions.updateSelectedArea, (state, { statePaths, overlap }) => ({
    ...state,
    currentSelection: statePaths, //feature?.get("statePath")
    selectionOverlap: overlap
  })),
  on(ScenarioActions.closeActiveScenario, state => ({
    ...state,
    currentSelection: undefined
  })),
  on(AreaActions.fetchUserDefinedAreasSuccess, (state, { userAreas }) => ({
    ...state,
    userArea: userAreas
  })),
  on(AreaActions.createUserDefinedAreaSuccess, (state, { userArea }) => ({
    ...state,
    userArea: {
      ...state.userArea,
      [userArea.id as number]: userArea
    }
  })),
  on(AreaActions.updateUserDefinedAreaSuccess, (state, { userArea }) => ({
    ...state,
    userArea: {
      ...state.userArea,
      [userArea.id as number]: userArea
    }
  })),
  on(AreaActions.deleteUserDefinedAreaSuccess, (state, { userAreaId }) => ({
    ...state,
    userArea: Object.values(state.userArea)
      .filter(({ id }) => id !== userAreaId)
      .reduce(
        (userAreas, userArea) => ({
          ...userAreas,
          [userArea.id]: userArea
        }),
        {}
      )
  })),
  on(AreaActions.fetchCalibratedCalculationAreasSuccess, (state, { calibratedAreas }) => ({
    ...state,
    calibratedCalculationAreas: calibratedAreas
  })),
  on(AreaActions.toggleVisibleArea, (state, { statePath }) => {
    return setIn(state, [...statePath, 'visible'], !getIn(state, [...statePath, 'visible'], false));
  }),
  on(AreaActions.fetchBoundariesSuccess, (state, { boundaries }) => ({
    ...state,
    boundaries
  })),
  on(AreaActions.addUserDefinedMatrix, (state, { matrix }) => ({
    ...state,
    userDefinedMatrices: updateIn(state, ['selectionMatrices', 'defaultArea', 'userDefinedMatrices'],
      oldMatrices => [...(oldMatrices as MatrixRef[]), matrix])
    })
  )
);
