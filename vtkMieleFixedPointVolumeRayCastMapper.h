//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#ifndef __vtkMieleFixedPointVolumeRayCastMapper_h
#define __vtkMieleFixedPointVolumeRayCastMapper_h

#include "vtkFixedPointVolumeRayCastMapper.h"

class VTKRENDERINGVOLUME_EXPORT vtkMieleFixedPointVolumeRayCastMapper : public vtkFixedPointVolumeRayCastMapper
{
    virtual const char* GetClassNameInternal() const override { return "vtkMieleFixedPointVolumeRayCastMapper"; }

public:
  static vtkMieleFixedPointVolumeRayCastMapper *New();
  void Render( vtkRenderer *, vtkVolume * ) override;

protected:
	vtkMieleFixedPointVolumeRayCastMapper();

private:
  vtkMieleFixedPointVolumeRayCastMapper(const vtkMieleFixedPointVolumeRayCastMapper&) = delete;
  void operator=(const vtkMieleFixedPointVolumeRayCastMapper&) = delete;
};
#endif
