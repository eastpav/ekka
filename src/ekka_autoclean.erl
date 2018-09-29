%% Copyright (c) 2018 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(ekka_autoclean).

-include("ekka.hrl").

-export([init/0, check/1]).

-record(?MODULE, {expiry, timer}).

init() ->
    case ekka:env(cluster_autoclean) of
        {ok, Expiry} -> timer_backoff(#?MODULE{expiry = Expiry});
        undefined    -> undefined
    end.

timer_backoff(State = #?MODULE{expiry = Expiry}) ->
    State#?MODULE{timer = ekka_node_monitor:run_after(Expiry div 4, autoclean)}.

check(State = #?MODULE{expiry = Expiry}) ->
    [maybe_clean(Member, Expiry) || Member <- ekka_membership:members(down)],
    [maybe_clean(M, Expiry) || M <- ekka_membership:members(stopped)],
    timer_backoff(State).

maybe_clean(#member{node = Node, ltime = LTime}, Expiry) ->
    case expired(LTime, Expiry) of
        true  -> ekka_cluster:force_leave(Node);
        false -> ok
    end.

expired(LTime, Expiry) ->
    timer:now_diff(erlang:timestamp(), LTime) div 1000 > Expiry.

