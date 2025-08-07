import Prim "mo:prim";
import List "mo:core/List";
import Debug "mo:core/Debug";
import Bool "mo:core/Bool";
import Nat "mo:core/Nat";
import HashMap "mo:hamt/HashMap";

persistent actor {

  // Prettier type wrapping a weak reference.
  // One can also add other kind of metadata if needed.
  type CacheValue<T> = {
    ref : Weak T;
  };

  // The seed for the hash map.
  let seed : HashMap.Seed = (13, 47);

  // A map of Nat64s to weak references pointing to the blobs.
  let cache = HashMap.new<Nat, CacheValue<[var Nat]>>(seed);

  // A list of blobs to be used by the program.
  // This program logic is simple and just keeps the objects in the list live,
  // and we expose a method to remove items from the list.
  // Removing items from this list will invalidate the weak references in the cache.
  // once the original items in the list get garbage collected.
  // In production, the program logic will be more complex and objects
  // could for example become unreachable so that they can be garbage collected,
  // which will produce a similar effect.
  var blobList = List.empty<[var Nat]>();

  public func addBlob(value : Nat) : async () {
    // Create a blob of 10MB full of 'value'.
    let blob = Prim.Array_init<Nat>(1024 * 1024 * 2, value);
    // Create a weak reference to the blob.
    let ref = Prim.allocWeakRef(blob);
    // Insert the weak reference into the cache.
    ignore HashMap.insert(cache, HashMap.nat, value, { ref = ref });
    // Add the blob to the list to be used by the program.
    List.add(blobList, blob);
  };

  public func getCacheSize() : async Nat {
    return HashMap.size(cache);
  };

  // Some attempt to pretty print the cache.
  public func showWeakRefs() : async () {
    Debug.print(" ========= ");
    for ((key, value) in HashMap.entries(cache)) {
      Debug.print(Nat.toText(key) # " --> " # Bool.toText(Prim.isLive(value.ref)));
    };
    Debug.print(" ========= ");
  };

  // Get the value from the cache.
  // Returns null if the value is not found or
  // the target of the weak reference is not live.
  public func getCacheValue(key : Nat) : async ?Nat {
    do ? {
      let innerVal = HashMap.get(cache, HashMap.nat, key)!;
      let blob = Prim.weakGet(innerVal.ref)!;
      blob[0];
    };
  };

  // Helper function to simulate program behavior that makes an object unreachable
  // such that later can be garbage collected.
  public func removeBlob(index : Nat) : async () {
    // Create a new blob with zeroes.
    let blob = Prim.Array_init<Nat>(1024 * 1024 * 2, 0);
    // Overwrite the element in the list at index with the new zero blob.
    List.put(blobList, index, blob);
  };

  // Helper to trigger a garbage collection event.
  // In production, this is not needed because the
  // application behavior will automatically trigger a GC.
  public func triggerGC() : async () {
    for (i in Nat.range(0, 10)) {
      let _arr = Prim.Array_init<Nat64>(1024 * 1024 * 2, 0);
      await async {};
    };
  };

};
