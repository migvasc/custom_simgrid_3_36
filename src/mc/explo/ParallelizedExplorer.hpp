/* Copyright (c) 2008-2024. The SimGrid Team. All rights reserved.          */

/* This program is free software; you can redistribute it and/or modify it
 * under the terms of the license (GNU LGPL) which comes with this package. */

#ifndef SIMGRID_MC_SAFETY_CHECKER_HPP
#define SIMGRID_MC_SAFETY_CHECKER_HPP

#include "src/mc/api/ClockVector.hpp"
#include "src/mc/api/states/State.hpp"
#include "src/mc/explo/Exploration.hpp"
#include "src/mc/explo/odpor/Execution.hpp"
#include "src/mc/explo/reduction/Reduction.hpp"
#include "src/mc/mc_config.hpp"

#include <condition_variable>
#include <deque>
#include <list>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace simgrid::mc {

class XBT_PRIVATE ParallelizedExplorer : public Exploration {
private:
  ReductionMode reduction_mode_;
  std::unique_ptr<Reduction> reduction_algo_;

  // For statistics
  unsigned long explored_traces_ = 0;

public:
  explicit ParallelizedExplorer(const std::vector<char*>& args, ReductionMode mode);
  void run() override;
  RecordTrace get_record_trace() override;
  void log_state() override;
  stack_t get_stack() override { return stack_; }

private:
  void backtrack();

  std::mutex opened_heads_lock_;
  std::condition_variable opened_heads_cv_;

  std::vector<std::shared_ptr<Reduction::RaceUpdate>> race_updates_;
  std::mutex race_updates_lock_;
  std::condition_variable race_updates_cv_;

  std::thread reducer;

  void Reducter();

  void Explorer();

  /** Stack representing the position in the exploration graph */
  stack_t stack_;

  /**
   * Provides additional metadata about the position in the exploration graph
   * which is used by SDPOR and ODPOR
   */
  odpor::Execution execution_seq_;

  /** Per-actor clock vectors used to compute the "happens-before" relation */
  std::unordered_map<aid_t, ClockVector> per_actor_clocks_;

  /** Opened states are states that still contains todo actors.
   *  When backtracking, we pick a state from it*/
  std::vector<StatePtr> opened_states_;
  StatePtr best_opened_state();

  /** Change current stack_ value to correspond to the one we would have
   *  had if we executed transition to get to state. This is required when
   *  backtracking, and achieved thanks to the fact states save their parent.*/
  void restore_stack(StatePtr state);

  RecordTrace get_record_trace_of_stack(stack_t stack);
};

} // namespace simgrid::mc

#endif