/* Copyright (c) 2007-2024. The SimGrid Team. All rights reserved.          */

/* This program is free software; you can redistribute it and/or modify it
 * under the terms of the license (GNU LGPL) which comes with this package. */

#ifndef SIMGRID_MC_SDPOR_HPP
#define SIMGRID_MC_SDPOR_HPP

#include "simgrid/forward.h"
#include "src/mc/explo/odpor/Execution.hpp"
#include "src/mc/explo/reduction/Reduction.hpp"

#include "src/mc/api/states/SleepSetState.hpp"
#include <memory>

namespace simgrid::mc {

class SDPOR : public Reduction {

public:
  SDPOR()           = default;
  ~SDPOR() override = default;

  class RaceUpdate : public Reduction::RaceUpdate {
    std::vector<std::pair<StatePtr, std::unordered_set<aid_t>>> state_and_choices_;

  public:
    RaceUpdate() = default;
    void add_element(StatePtr state, std::unordered_set<aid_t> choices)
    {
      state_and_choices_.emplace_back(state, choices);
    }
    std::vector<std::pair<StatePtr, std::unordered_set<aid_t>>> get_value() { return state_and_choices_; }
  };

  std::shared_ptr<Reduction::RaceUpdate> races_computation(odpor::Execution& E, stack_t* S,
                                                           std::vector<StatePtr>* opened_states) override
  {

    State* s = S->back().get();
    // let's look for race only on the maximal executions
    if (not s->get_enabled_actors().empty())
      return std::make_shared<RaceUpdate>();

    auto updates = std::make_shared<RaceUpdate>();

    for (auto e_prime = static_cast<odpor::Execution::EventHandle>(0); e_prime <= E.get_latest_event_handle();
         ++e_prime) {

      auto E_prime = E.get_prefix_before(e_prime + 1);
      for (const auto e_race : E_prime.get_reversible_races_of(e_prime)) {

        State* prev_state  = (*S)[e_race].get();
        const auto choices = E_prime.get_missing_source_set_actors_from(e_race, prev_state->get_backtrack_set());
        if (not choices.empty())
          updates->add_element((*S)[e_race], choices);
      }
    }
    return updates;
  }

  unsigned long apply_race_update(std::shared_ptr<Reduction::RaceUpdate> updates,
                                  std::vector<StatePtr>* opened_states = nullptr) override
  {
    auto sdpor_updates = static_cast<SDPOR::RaceUpdate*>(updates.get());

    unsigned long nb_updates = 0;

    for (auto& [state, choices] : sdpor_updates->get_value()) {
      state->ensure_one_considered_among_set(choices);
      if (opened_states != nullptr) {
        opened_states->emplace_back(state);
        nb_updates++;
      }
    }
    return nb_updates;
  }

  StatePtr state_create(RemoteApp& remote_app, StatePtr parent_state) override
  {
    auto res             = Reduction::state_create(remote_app, parent_state);
    auto sleep_set_state = static_cast<SleepSetState*>(res.get());

    if (not sleep_set_state->get_enabled_minus_sleep().empty()) {
      sleep_set_state->consider_best();
    }

    return res;
  }

  aid_t next_to_explore(odpor::Execution& E, stack_t* S) override
  {
    if (S->back()->get_batrack_minus_done().empty())
      return -1;
    return S->back()->next_transition_guided().first;
  }
};

} // namespace simgrid::mc

#endif