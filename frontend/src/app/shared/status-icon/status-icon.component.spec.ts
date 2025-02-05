import { ComponentFixture, TestBed, waitForAsync } from '@angular/core/testing';

import { StatusIconComponent } from './status-icon.component';

describe('StatusIconComponent', () => {
  let fixture: ComponentFixture<StatusIconComponent>,
      component: StatusIconComponent;

  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
      declarations: [ StatusIconComponent ]
    })
    .compileComponents();
    fixture = TestBed.createComponent(StatusIconComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  }));

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
