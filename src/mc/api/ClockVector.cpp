/* Copyright (c) 2015-2024. The SimGrid Team. All rights reserved.          */

/* This program is free software; you can redistribute it and/or modify it
 * under the terms of the license (GNU LGPL) which comes with this package. */

#include "src/mc/api/ClockVector.hpp"

namespace simgrid::mc {

ClockVector ClockVector::max(const ClockVector& cv1, const ClockVector& cv2)
{
  auto max_vector = ClockVector(cv1);

  for (const auto& [aid, value] : cv2.contents_)
    max_vector[aid] = std::max(value, max_vector.get(aid).value_or(0));

  return max_vector;
}

} // namespace simgrid::mc
