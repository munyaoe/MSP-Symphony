import { ComponentFixture, TestBed, waitForAsync } from '@angular/core/testing';
import { SharedModule } from '@src/app/shared/shared.module';

import { AreaGroupComponent } from './area-group.component';
import { TranslateModule, TranslateService } from "@ngx-translate/core";
import { TranslationSetupModule } from "@src/app/app-translation-setup.module";

describe('AreaGroupComponent', () => {
  let fixture: ComponentFixture<AreaGroupComponent>,
      component: AreaGroupComponent;

  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
      declarations: [ AreaGroupComponent ],
      imports: [ SharedModule, TranslationSetupModule ]
    }).compileComponents();
    fixture = TestBed.createComponent(AreaGroupComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  }));

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
