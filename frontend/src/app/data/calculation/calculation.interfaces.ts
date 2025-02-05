import { ChartData } from '@src/app/report/pressure-chart/pressure-chart.component';
import { Extent } from 'ol/extent';
import { ProjectionLike } from "ol/proj";
import { NormalizationOptions } from "@data/calculation/calculation.service";
import { BandType } from "@data/metadata/metadata.interfaces";
import { ChangesProperty } from '@data/scenario/scenario.interfaces';
import { ListItemsSort, SortableListItem } from "@data/common/sorting.interfaces";

// TODO Move calculation element to Scenario state
export interface State {
  loadingReport: boolean;
  calculations: CalculationSlice[];
  loadingCalculations: boolean;
  calculating: boolean;
  legends: LegendState;
  percentileValue: number;
  sortCalculations: ListItemsSort;
  batchProcesses: { [key: number]: BatchCalculationProcessEntry },
  visibleResults: number[];
  loadingResults: number[];
  loadingReports: number[];
}

export interface Report {
  baselineName: string;
  operationName: string;
  operationOptions: OperationParams;
  name: string;
  total: number;
  average: number;
  min: number;
  max: number;
  stddev: number;
  histogram: number[];
  geographicalArea: number; // m^2
  calculatedPixels: number;
  gridResolution: number; // [m]
  areaMatrices: AreaMatrix[];
  normalization: NormalizationOptions;
  impactPerPressure: Record<string, number>;
  impactPerEcoComponent: Record<string, number>;
  scenarioChanges: ReportChanges;
  chartData: ChartData;
  chartWeightThreshold: number;
  timestamp: number;
  overflow: Record<BandType, number[]> | null;
}

export interface ReportChanges {
  baseChanges: {
    [key: string] : ChangesProperty
  },
  areaChanges: {
    [key: number]: {
      [key: string] : ChangesProperty
    }
  };
}

export interface ComparisonReport {
  a: Report,
  b: Report
  chartDataPositive: ChartData;
  chartDataNegative: ChartData;
}

export interface StaticImageOptions {
  url: string;
  calculationId: number;
  imageExtent: Extent;
  projection: ProjectionLike;
  interpolate: boolean;
}

export interface CalculationSlice extends SortableListItem {
  id: number;
  isPurged: boolean;
}

export type LegendType = 'result' | 'comparison' | 'ecosystem' | 'pressure';

export interface LegendColor {
  color: string;
  quantity: number;
  opacity?: number;
}

export interface Legend {
  unit: string;
  colorMap: LegendColor[];
}

export interface PercentileResponse {
  percentileValue: number;
}

export interface BatchCalculationProcessEntry {
  id: number;
  cancelled: boolean;
  currentEntity: number|null;
  entities: number[];
  calculated: number[];
  failed: number[];
  reports: number|null[];
  isAreaCalculation: boolean;
  entityNames: { [key: number]: string };
}

export interface ComparisonLegendState {
  title: string[]
  legend: Legend,
}

export interface LegendState {
  result: Legend | undefined,
  ecosystem: Legend | undefined,
  pressure: Legend | undefined,
  comparison: { [value: string] : ComparisonLegendState }
}

export interface OperationParams {
  [param: string]: string;
}

export interface AreaMatrix {
  areaName: string;
  matrix: string;
}
