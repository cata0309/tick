const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct{
  id: Gbe.EntityId,
  pickup: *const C.Pickup,
};

pub const run = GbeSystem.build(GameSession, SystemData, process);

fn process(gs: *GameSession, self: SystemData) bool {
  var it = gs.gbe.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
    const other_player = gs.gbe.find(event.other_id, C.Player) orelse continue;
    _ = Prototypes.EventConferBonus.spawn(gs, C.EventConferBonus{
      .recipient_id = event.other_id,
      .pickup_type = self.pickup.pickup_type,
    });
    return false;
  }
  return true;
}
