import { CustomColors } from '@kit.ArkUI';

export class AppColors implements CustomColors {
  public brand: ResourceColor = $r('app.color.meow_brand');
  public iconSubEmphasize: ResourceColor = $r('app.color.meow_iconSubEmphasize');
  public compEmphasizeSecondary: ResourceColor = $r('app.color.meow_iconSubEmphasize');
  public compEmphasizeTertiary: ResourceColor = $r('app.color.meow_iconSubEmphasize');
}

export class meowTheme implements CustomTheme {
  public colors: AppColors = new AppColors();
}