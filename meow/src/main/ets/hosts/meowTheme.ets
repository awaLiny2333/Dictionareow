import { CustomColors } from '@kit.ArkUI';

export class AppColors implements CustomColors {
  public brand: ResourceColor = $r('app.color.meow_brand');
  public icon_sub_emphasize: ResourceColor = $r('app.color.meow_iconSubEmphasize');
  public comp_emphasize_secondary: ResourceColor = $r('app.color.meow_iconSubEmphasize');
  public comp_emphasize_tertiary: ResourceColor = $r('app.color.meow_iconSubEmphasize');
}

export class meowTheme implements CustomTheme {
  public colors: AppColors = new AppColors();
}