import { events, transactions } from "@amxx/graphprotocol-utils";
import { Bytes } from "@graphprotocol/graph-ts";
import { fetchCounter } from "../fetch/counter";
import {
  CounterIncremented as CounterIncrementedEvent,
} from "../generated/counter/Counter";
import { CounterIncremented } from "../generated/schema";

export function handleCounterIncremented(event: CounterIncrementedEvent): void {
  const contract = fetchCounter(event.address);

  const ev = new CounterIncremented(events.id(event));
  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.currentValue = event.params.currentValue;
  ev.save();

  contract.currentValue = event.params.currentValue;
  contract.save();
}