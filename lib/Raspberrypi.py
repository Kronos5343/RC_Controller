import time
import pydbus

def make_discoverable_and_pairable(timeout=120, alias="RaspberryPi_RC_Car"):
    """
    Makes the Raspberry Pi's Bluetooth adapter discoverable and pairable.

    Args:
        timeout (int): Duration in seconds for discoverability (0 for infinite).
        alias (str): The name displayed to other devices.
    """
    BUS_NAME = 'org.bluez'
    ADAPTER_PATH = '/org/bluez/hci0' # hci0 is the default adapter

    try:
        # Get the system bus
        sys_bus = pydbus.SystemBus()
        # Get the Bluetooth adapter object
        adapter = sys_bus.get(BUS_NAME, ADAPTER_PATH)

        # Set the device name (Alias is read/write, Name is read-only)
        adapter.Alias = alias
        print(f"Bluetooth name set to: {adapter.Alias}")

        # Set the adapter to be pairable and discoverable
        adapter.Pairable = True
        adapter.Discoverable = True
        adapter.DiscoverableTimeout = dbus.UInt32(timeout)

        print(f"Bluetooth adapter set to: Pairable={adapter.Pairable}, Discoverable={adapter.Discoverable}")

        if timeout == 0:
            print("Discoverable indefinitely. Press Ctrl+C to stop.")
            while True:
                time.sleep(1)
        else:
            print(f"Discoverable for {timeout} seconds. Waiting for connection...")

        # Revert discoverable mode after timeout if not infinite
        if timeout != 0:
            adapter.Discoverable = False
            print("Discoverability timed out and disabled.")

    except Exception as e:
        print(f"An error occurred: {e}")
        print("Ensure the Bluetooth service is running and you have sufficient permissions (try >

if __name__ == '__main__':
    import dbus # dbus is needed for the UInt32 type

    # --- Configuration ---
    DISCOVER_TIMEOUT = 0 # 0 means infinite discoverability
    DEVICE_NAME = "My_RC_Car_Pi"
    # ---------------------

    # Note: Running scripts that interact with BlueZ via DBus often requires root
    # privileges, so you will likely need to run this with 'sudo python3 bt_discoverable.py'
    make_discoverable_and_pairable(timeout=DISCOVER_TIMEOUT, alias=DEVICE_NAME)