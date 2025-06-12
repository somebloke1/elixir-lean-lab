
# **Crafting an Absolutely Minimal Linux System with Elixir Execution for Virtualized Environments**

## **1\. Introduction**

### **1.1. The Challenge: Achieving an "Absolutely Minimal" Linux System with Elixir Execution in a Virtualized Environment**

The pursuit of an "absolutely minimal" Linux system presents a fascinating engineering challenge, particularly when such a system must also support the execution of applications built with a modern, powerful language like Elixir. Elixir's runtime, the BEAM (Erlang Virtual Machine), while renowned for its concurrency and fault tolerance, brings its own set of dependencies and a baseline footprint. Thus, the core problem lies in meticulously balancing extreme system minimality—stripping the Linux kernel and root filesystem to their bare essentials—with the functional requirements of the BEAM. This endeavor is non-trivial; it demands careful selection and configuration of every component, from the lowest levels of the kernel to the application runtime itself, all while ensuring stable operation within a virtualized environment. The goal is not just to create a small system, but one that is precisely tailored and robust enough for its intended Elixir workload.

### **1.2. Overview of Approaches to be Discussed**

This report will explore various strategies and methodologies to construct such a minimal, Elixir-capable Linux system for virtual machine (VM) deployment. The discussion will navigate through several key areas:

* **Kernel Customization:** Techniques for tailoring the Linux kernel to include only essential features, significantly reducing its size and attack surface.  
* **Root Filesystem Construction:** Methods for building a minimal root filesystem (RFS) containing only the necessary libraries, utilities, and the Elixir runtime.  
* **Build System Evaluation:** An analysis of prominent embedded Linux build systems—Buildroot, the Yocto Project, and the Nerves Project—assessing their suitability for this specific task.  
* **Elixir Integration:** Strategies for incorporating the Erlang/OTP platform and Elixir into the minimal system, including application packaging.  
* **VM-Specific Optimizations:** Kernel configurations crucial for efficient performance within a virtualized environment, particularly QEMU.  
* **Deployment Strategies:** Guidance on building bootable images and launching them in a VM.

This comprehensive exploration aims to provide a clear understanding of the viable pathways to achieve the desired outcome.

### **1.3. Defining "Minimal Footprint" in Context**

The term "minimal footprint" can be interpreted in several ways. For kernel developers focused on deep-embedded systems, a minimal kernel might be well under a megabyte.1 However, when considering a system that must run Elixir applications, the BEAM virtual machine and its associated Erlang/OTP libraries introduce a non-negligible baseline size. For instance, Nerves firmware images, which are highly optimized for Elixir, typically start in the 18-30 MB range.2 Therefore, in the context of this report, "minimal footprint" will be defined as achieving the smallest possible system size—encompassing the kernel, root filesystem, and all Elixir runtime components—that robustly supports Elixir application execution within a VM.

The concept of a "minimal footprint" is multi-layered. It involves minimization at the kernel level (stripping unnecessary drivers and features), the root filesystem level (excluding Elixir/BEAM, focusing on essential utilities and libraries), and finally, the total system image size (which will inevitably include the Elixir runtime). The strategies discussed will focus on minimizing everything *around* the BEAM, as the BEAM itself represents a largely irreducible core component for Elixir execution.

Furthermore, the virtual machine context significantly influences what constitutes a minimal configuration. Running within a VM allows for the omission of a wide array of physical hardware drivers (e.g., for specific Wi-Fi chips, sound cards, or exotic bus controllers) that would be necessary for bare-metal systems. Conversely, it mandates the inclusion of VM-specific paravirtualized drivers, such as VirtIO, for efficient operation of network, storage, and console I/O. This leads to a *different* kind of minimal configuration compared to one designed for physical hardware, potentially smaller in some areas (fewer physical drivers) but with specific additions for virtualization.

## **2\. Core Strategies for System Minimization**

Achieving a minimal Linux system requires a meticulous approach to both kernel configuration and root filesystem construction. The aim is to include only what is absolutely necessary for the system to boot, support the virtualized environment, and execute Elixir applications.

### **2.1. Kernel Customization: Sculpting the Core**

The Linux kernel is highly configurable, allowing for the creation of very lean builds.

* **Leveraging tinyconfig as a Baseline**  
  A highly effective starting point for a minimalist kernel is the make tinyconfig target.1 This command generates a  
  .config file with an extremely small set of enabled options, often disabling hundreds or even thousands of features typically found in default or distribution kernels. For example, one analysis noted that tinyconfig resulted in only 247 enabled configuration options compared to 2071 for a stock Debian kernel.1 This approach provides a clean slate, forcing the developer to consciously add back only those features that are strictly necessary for the target system's functionality. It shifts the paradigm from trying to remove unwanted features (which can be complex due to interdependencies) to a more controlled process of targeted inclusion.  
* **Manual Kconfig Exploration and Essential Options**  
  After generating a tinyconfig, further customization is performed using tools like make menuconfig, make nconfig, or make xconfig. Several options are fundamental for a bootable, usable system, especially in a VM context:  
  * **Enable TTY for console support:** This is essential for basic interaction, debugging, and seeing console output from user-space applications.1 This option is typically found under  
    Device Drivers \> Character devices \> Enable TTY.  
  * **Enable printk for kernel messages:** printk provides the mechanism for the kernel to output messages, which are crucial for diagnosing boot-time issues and kernel-level problems.1 It is located at  
    General setup \> Configure standard kernel features (expert users) \> Enable support for printk. While disabling printk can save a small amount of space (as experimented in 1), it makes debugging extremely difficult and is generally not recommended, especially during development or for VM environments where console access is readily available. The definition of "essential" can be tied to the stage of development; for initial bring-up and testing,  
    printk and TTY are indispensable. For a final, highly stable production image where every byte is critical, printk *could* be considered for removal, but this carries significant risk.  
  * **Enable ELF binary support:** To execute any user-space programs, including the init process and eventually the Elixir runtime, the kernel must be able to load and run ELF (Executable and Linkable Format) binaries.1 This is found under  
    Executable file formats / Emulations \> Kernel support for ELF binaries.  
  * **Enable initramfs/initrd support:** If the root filesystem is intended to be loaded into RAM at boot (a common strategy for minimal systems), this option is required.1 It can be enabled via  
    General setup \> Initial RAM filesystem and RAM disk (initramfs/initrd) support.  
  * **64-bit kernel:** While a 32-bit kernel is technically smaller, most modern VMs and Elixir itself benefit from a 64-bit environment for performance and address space reasons.1 The choice depends on the target VM's capabilities and the application's performance requirements. For general Elixir use, 64-bit is usually preferred.

The process of kernel configuration, starting from tinyconfig, encourages a mindset of only adding features explicitly known to be required. This is generally more effective for achieving true minimality than starting with a more comprehensive default configuration and attempting to remove components, as hidden dependencies can make removal a frustrating and error-prone process.

### **2.2. Minimal Root Filesystem (RFS): The User-Space Foundation**

The root filesystem contains all the user-space programs, libraries, and configuration files needed by the system.

* **Building an initramfs (Initial RAM Filesystem)**  
  An initramfs is a CPIO (Copy In, Copy Out) archive, typically compressed with gzip or xz, that contains a complete, minimal root filesystem. The kernel loads this archive into RAM during the early boot process and mounts it as the initial root.1 This approach is well-suited for minimal VMs as it can eliminate the need for a persistent virtual block device for the root filesystem, simplifying the VM setup and potentially speeding up boot times.

  The creation of an initramfs involves packaging a directory structure containing the RFS components using cpio and a compression utility like gzip.1 Build systems like Buildroot can also automatically generate a  
  rootfs.cpio.gz image.7 The kernel must be configured with  
  CONFIG\_INITRAMFS\_SOURCE pointing to the path of this CPIO archive if it's to be embedded directly into the kernel image, or it can be loaded separately by the bootloader or QEMU.8  
* **Utilizing BusyBox for Essential Utilities**  
  BusyBox is a cornerstone of minimal Linux systems. It combines trimmed-down versions of many common UNIX command-line utilities (e.g., sh, ls, mount, init) into a single, small executable.1 This significantly reduces the RFS size compared to including full-fledged versions of these tools. BusyBox itself is configurable via a  
  menuconfig-like interface, allowing developers to select only the necessary applets.  
  For maximal RFS simplicity, BusyBox can be built as a statically linked binary (Build BusyBox as a static binary (no shared libs)).9 This removes its dependency on an external C library. However, it's important to note that the Elixir runtime (BEAM) will still require a C library to be present in the RFS.  
* **Basic RFS Structure**  
  A minimal RFS must contain a few essential directories to conform to the Linux filesystem hierarchy and provide necessary mount points 9:  
  * /bin: Essential user command binaries (often symlinked to BusyBox).  
  * /sbin: Essential system binaries (often symlinked to BusyBox).  
  * /etc: Host-specific system configuration files.  
  * /dev: Device files (can be populated by devtmpfs or mdev).  
  * /proc: Virtual filesystem for process information.  
  * /sys: Virtual filesystem for system/device information.  
  * /lib: Essential shared libraries and kernel modules.  
  * /usr: Secondary hierarchy for user data (may contain /usr/bin, /usr/sbin, /usr/lib).

A minimal initialization script, typically /etc/init.d/rcS or a script executed by /etc/inittab if using BusyBox init, is required to perform tasks like mounting /proc, /sys, and /dev (if using devtmpfs), setting up networking (if needed), and eventually launching the BEAM to run the Elixir application.9

* **Choosing a C Standard Library (Libc)**  
  The choice of C standard library is critical for both RFS size and compatibility. The main options are:  
  * **musl libc**: A lightweight, modern libc designed for static linking and correctness. Often preferred for new minimal systems.  
  * **uClibc-ng**: A fork of uClibc, designed for embedded systems with a focus on small size.  
  * **glibc (GNU C Library)**: The standard libc on most desktop and server Linux distributions, offering extensive features and compatibility but with a larger footprint.

Both musl libc and uClibc-ng are significantly smaller than glibc.7 Buildroot and Yocto support all three, allowing selection based on project needs. For instance, a comparison showed Buildroot usinguClibc-ng resulting in a smaller RFS than Yocto using musl, though the kernel size was larger in the Buildroot case; switching Buildroot to musl increased its RFS size somewhat.7The BEAM virtual machine and any Elixir Native Implemented Functions (NIFs) must be compiled against and compatible with the chosen libc. This makes the libc choice a critical trade-off. While musl or uClibc-ng are attractive for their size, glibc offers the broadest compatibility and a richer feature set, which might be implicitly relied upon by complex NIFs or development tools. For an "absolutely minimal" system, musl is a strong contender, but thorough testing of the entire Elixir application stack with it is paramount.Regarding linking, while BusyBox can be statically linked, the BEAM and Elixir applications typically link dynamically against the chosen C library and other system libraries. Achieving a fully statically linked BEAM is uncommon and complex. Therefore, the focus should be on selecting a minimal dynamic C library that meets the application's needs.

## **3\. Choosing the Right Build System for a Minimal Elixir Environment**

Selecting an appropriate build system is pivotal for efficiently creating and managing a minimal Linux system tailored for Elixir. Buildroot, the Yocto Project, and the Nerves Project each offer distinct advantages and methodologies.

### **3.1. Buildroot**

Buildroot is renowned for its simplicity and efficiency in generating embedded Linux systems. It employs a straightforward approach based on Makefiles and Kconfig, similar to the Linux kernel's configuration system.11

* Strengths for Minimal Footprint:  
  Buildroot's design philosophy prioritizes simplicity and aims for small default image sizes.13 Minimal images (kernel \+ RFS, before adding Elixir/BEAM) can be around 2 MB according to some analyses 13, or closer to 4.8 MB in other comparisons.7 It generally offers faster build times compared to more complex systems like Yocto.11 The  
  menuconfig interface provides an intuitive way to select packages and configure system components.14  
* Process for Creating a Minimal System:  
  The process typically starts by selecting a minimal default configuration (defconfig), such as qemu\_x86\_64\_virt\_defconfig for a QEMU x86-64 target, which is then heavily customized.11 Using  
  make menuconfig, developers can deselect unneeded packages, configure the kernel (often by pointing to a custom kernel .config file), fine-tune BusyBox, and choose a C library (e.g., uClibc-ng or musl). Filesystem image types, such as CPIO for an initramfs, can also be selected.7  
* Integrating Elixir and Erlang/OTP:  
  Buildroot includes package definitions for Erlang/OTP (erlang.mk) and Elixir (elixir.mk), which handle the fetching, cross-compilation, and installation of these components.15 A highly recommended approach for managing custom applications and system configurations is to use Buildroot's external mechanism (  
  BR2\_EXTERNAL). The buildroot\_elixir project serves as an excellent reference implementation of an external tree for building Elixir-enabled systems.17 When building Elixir, which itself is written in Elixir, careful attention must be paid to dependencies like  
  HOST\_ELIXIR\_DEPENDENCIES, which may need to point to a host-compiled Erlang if Elixir is being compiled on the host for the target.15 Custom Elixir applications, typically packaged as Mix releases, can be integrated into the rootfs using Buildroot's package infrastructure (e.g., by creating a generic package or a custom  
  .mk file) or by using rootfs overlays.8  
* Weaknesses:  
  A significant characteristic of Buildroot is that it typically rebuilds the entire system if major configuration options (like toolchain settings) are changed.13 It is also considered less flexible than Yocto for managing multiple product variants from a single configuration base.19  
  Buildroot's directness and simplicity are powerful assets for creating a single, highly optimized image. The main challenge for an Elixir system lies in correctly configuring the Erlang/OTP and Elixir packages, ensuring version compatibility, and satisfying all build-time (host) and runtime (target) dependencies. Projects like buildroot\_elixir demonstrate robust solutions to these challenges.17 Furthermore, Buildroot's  
  BR2\_ROOTFS\_OVERLAY and BR2\_ROOTFS\_POST\_BUILD\_SCRIPT features are crucial for final customizations. The overlay mechanism allows for the easy addition of pre-built Elixir releases or custom configuration files directly into the target filesystem structure.8 Post-build scripts can then perform final adjustments, such as setting up specific permissions or symbolic links required by the Elixir application after all packages are installed but before the final image is created.18

### **3.2. Yocto Project**

The Yocto Project is a collaborative open-source initiative that provides a comprehensive set of tools, templates, and methods for creating custom Linux-based systems. It uses BitBake as its build engine, with build instructions organized into recipes and layers, offering high flexibility.19

* Strengths:  
  The Yocto Project excels in flexibility and scalability, making it well-suited for managing complex systems and diverse product variants sharing a common software base.13 It enjoys strong industry support, with many silicon vendors providing Board Support Packages (BSPs) as Yocto layers.19 A key advantage is its support for incremental builds; BitBake intelligently rebuilds only those components that have changed or whose dependencies have changed.13  
* Process for Creating a Minimal System:  
  To achieve a minimal footprint with Yocto, it is advisable to use a minimal distribution configuration, such as poky-tiny.7 Further customization involves modifying the  
  local.conf file to remove unwanted features and packages. Using this approach, a core-image-minimal build (kernel \+ RFS, before Elixir) was reported to be around 3.6 MB.7  
* Integrating Elixir and Erlang/OTP:  
  The meta-erlang layer is the standard mechanism for adding Erlang and Elixir support to a Yocto build.22 This layer provides recipes for various versions of Erlang, Elixir, and common BEAM-based applications like Livebook and RabbitMQ. The layer is added to the build configuration using  
  bitbake-layers add-layer../meta-erlang.23 Specific versions of Erlang and Elixir can be selected by setting variables like  
  PREFERRED\_VERSION\_erlang and PREFERRED\_VERSION\_elixir in local.conf.23  
* Weaknesses for Minimal Footprint Focus:  
  The Yocto Project has a notoriously steep learning curve and inherent complexity 13; BitBake itself is a substantial Python application.13 Initial build times can be lengthy, and the disk space requirements are significant (typically 25-50 GB or more).7 Error messages from BitBake can sometimes be cryptic and difficult to diagnose.14  
  While Yocto is powerful, its extensive capabilities might be overkill for constructing a single, minimal VM image primarily focused on running Elixir. The overhead of learning and managing Yocto's layer-based architecture and recipe syntax may not be justified if the goal is a one-off, highly optimized image. Its strengths in managing hardware variants and complex, multi-component software stacks are less pertinent in this specific scenario. It's crucial to understand that achieving a minimal footprint with Yocto necessitates leveraging specific configurations like "Poky-Tiny," as standard Poky builds are not inherently designed for extreme minimality.7

### **3.3. Nerves Project**

The Nerves Project is an open-source platform and associated tooling specifically designed to build lean, production-grade embedded systems using Elixir. It achieves this by leveraging Buildroot for the underlying Linux system and kernel construction.2

* Strengths for Elixir Focus:  
  Nerves is fundamentally Elixir-centric, designed from the ground up to provide an optimal environment for Elixir applications.2 It promotes a "lean by design" philosophy, using Elixir Mix releases to include only the code essential for the application. Firmware sizes typically start in the 20-30 MB range, which includes the Linux kernel, a minimal root filesystem, the Erlang/OTP runtime, and a basic Elixir application 2; an older presentation mentioned sizes around 18 MB.3 While based on Buildroot, Nerves abstracts much of Buildroot's complexity, offering a more streamlined experience for Elixir developers.2 A key component is  
  erlinit, a minimal init process that is responsible for starting the Erlang runtime (BEAM) very early in the boot process (often as PID 1 or shortly thereafter). The BEAM then takes over the role of supervising the main Elixir application.24 Nerves provides "Nerves Systems," which are pre-configured Buildroot setups for common hardware platforms like Raspberry Pi and BeagleBone, simplifying deployment on these targets. A generic  
  nerves\_system\_x86\_64 is available for x86-64 targets, suitable for VMs.24  
* Process for Creating a System:  
  Nerves projects are managed using Elixir's mix build tool. Developers select an appropriate Nerves System (e.g., nerves\_system\_x86\_64 for a VM), develop their Elixir application as usual, and then build the complete firmware image using the mix firmware command.  
* Integrating Elixir and Erlang/OTP:  
  This is handled automatically and seamlessly by the Nerves tooling, which ensures that compatible versions of Erlang/OTP and Elixir are used and correctly configured for the target system.  
* Weaknesses/Considerations:  
  Nerves primarily targets physical embedded hardware, although generic systems like nerves\_system\_x86\_64 facilitate VM deployment.24 The baseline minimal footprint of 20-30 MB 2 is significantly larger than what can be achieved for just a kernel and a BusyBox-based RFS, primarily due to the inclusion of the complete Erlang/OTP runtime. This is an important baseline for users to understand. While Nerves simplifies many aspects, it offers less direct, granular control over the low-level Buildroot configuration compared to using Buildroot directly, though creating custom Nerves Systems allows for deeper customization if needed.  
  Nerves provides the most integrated and streamlined experience for running Elixir on a minimal Linux platform, especially if its conventions and supported base systems (like generic x86\_64 for a VM) align with the project's requirements. It effectively abstracts away the complexities of cross-compiling the BEAM and configuring Buildroot specifically for Elixir. The erlinit approach 25 is highly optimized for an Elixir-first system architecture. Nerves effectively redefines the "system" from an Elixir developer's perspective: the BEAM is not just another application running on Linux; it becomes the primary application supervisor for the entire user-space portion of the system.25 This is a paradigm shift from traditional embedded Linux, where an  
  init process like systemd or BusyBox init manages services. While highly efficient for Elixir applications, this means the resulting system is less of a general-purpose Linux environment and more of a dedicated Elixir appliance.

### **3.4. Comparative Analysis and Recommendation Strategy**

The choice of build system depends heavily on the project's specific priorities regarding minimality, Elixir integration, development effort, and control.

**Table 1: Comparative Analysis of Build Systems for Minimal Elixir VM**

| Feature | Buildroot | Yocto Project | Nerves Project |
| :---- | :---- | :---- | :---- |
| **Learning Curve** | Moderate; Makefiles/Kconfig familiarity helps 14 | Steep; complex layers, recipes, BitBake 13 | Low for Elixir devs; abstracts Buildroot 2 |
| **Complexity** | Low to Moderate; simple core 13 | High; powerful but intricate 13 | Low (for user); complexity handled by Nerves tooling |
| **Typical Minimal Image with Elixir** | Kernel+RFS \~2-5MB \+ BEAM/Elixir (est. 15-25MB total) 7 | Kernel+RFS \~3.6MB \+ BEAM/Elixir (est. 18-28MB total) 7 | \~18-30MB (includes Kernel, RFS, BEAM, basic Elixir app) 2 |
| **Elixir Integration Method** | elixir.mk/erlang.mk packages; BR2\_EXTERNAL for apps 15 | meta-erlang layer 22 | Native, core part of the tooling and system design 2 |
| **Build Time (Initial/Incremental)** | Fast initial; full rebuilds common 11 | Slow initial; fast incremental 13 | Moderate initial (Buildroot backend); good incremental for app changes |
| **Customization Granularity** | High; direct Kconfig/Makefile control | Very High; layers and recipes offer fine-grained control | Moderate; custom Nerves systems for deep changes, app-level focus otherwise |
| **Community/Ecosystem** | Strong embedded community | Very strong, large industry backing, many layers 19 | Active Elixir/embedded niche community |
| **Suitability for "Absolutely Minimal Elixir VM"** | Good, if deep control over base Linux and smallest non-Elixir parts is key. | Possible (with Poky-Tiny), but likely overkill and more complex than needed. | Excellent, if "minimal" means the smallest self-contained *Elixir system*. |

* **Recommendation Logic:**  
  * For projects where the **absolute focus is on running Elixir with the least development overhead** on a minimal Linux base, and a generic x86\_64 Nerves system is sufficient, the **Nerves Project** is highly compelling. Its baseline image size already includes a functional BEAM.  
  * For scenarios requiring **more granular control over the base Linux system**, or if Nerves' abstractions are too high-level, but still aiming for minimality and relative simplicity in the build process, **Buildroot** is the recommended choice. It allows for a smaller non-Elixir footprint, onto which Elixir/BEAM can be added.  
  * If the project is anticipated to **expand significantly to support many hardware variants or incorporate a complex software stack beyond just Elixir**, and the development team has the resources or willingness to invest in the learning curve, the **Yocto Project** becomes a viable, albeit more complex, option. However, for the specific query of a single minimal Elixir VM, it is likely overkill.

The "best" choice is contingent on how the user defines "minimal" and their potential long-term goals beyond this specific VM. If "minimal" means the smallest possible, self-contained system that *just runs Elixir* with good tooling support, Nerves is optimized for this. If "minimal" implies creating the smallest possible generic Linux base onto which Elixir is *one* of the components, and the user desires deep understanding and control over that base, Buildroot offers a more direct path. The VM context simplifies hardware concerns, making Nerves' generic nerves\_system\_x86\_64 24 or a QEMU-specific

defconfig in Buildroot 11 very practical starting points.

## **4\. Kernel Configuration for Virtualized Environments (VMs)**

When targeting a virtual machine, specific kernel configurations are essential for optimal performance and functionality. The focus shifts from supporting diverse physical hardware to enabling efficient communication with the hypervisor's paravirtualized devices.

### **4.1. VirtIO Drivers: The Key to VM Performance**

VirtIO is an open standard that defines an abstraction layer over devices in a paravirtualized hypervisor. VirtIO devices allow guests to achieve high performance for I/O operations by providing a standardized interface to the hypervisor, avoiding the overhead of emulating legacy hardware.26 For any VM aiming for efficiency, enabling VirtIO drivers is crucial.

* Enabling Core VirtIO Support:  
  The primary Kconfig option to enable VirtIO support is CONFIG\_VIRTIO=y (or m if building as a module). This is typically found under Device Drivers \> Virtio drivers.27  
* **Essential VirtIO Device Drivers:**  
  * **VirtIO Block Device (CONFIG\_VIRTIO\_BLK):** Necessary for accessing virtual hard disks or any block storage provided by the hypervisor with good performance. This option is located at Device Drivers \> Block devices \> Virtio block driver.27  
  * **VirtIO Network Device (CONFIG\_VIRTIO\_NET):** Required for efficient virtual network interfaces. Found under Device Drivers \> Network device support \> Virtio network driver.29  
  * **VirtIO Console (CONFIG\_VIRTIO\_CONSOLE):** Provides a paravirtualized serial console, enabling communication between the guest and the VM host. This is often essential for debugging and initial interaction. Located at Device Drivers \> Character devices \> Virtio console.27  
* **Other Useful VirtIO Devices (Optional but good to be aware of):**  
  * CONFIG\_VIRTIO\_PCI: Enables VirtIO devices exposed over a virtual PCI bus, a common transport mechanism.  
  * CONFIG\_VIRTIO\_MMIO: Enables VirtIO devices exposed via Memory-Mapped I/O.  
  * CONFIG\_HW\_RANDOM\_VIRTIO: Provides access to the host's entropy pool via a VirtIO Random Number Generator, which can be important for cryptographic operations within the guest.27  
  * CONFIG\_VIRTIO\_BALLOON: Allows the guest's memory to be dynamically adjusted by the hypervisor (memory ballooning).27 While potentially useful for managing memory resources in a larger virtualization deployment, for an "absolutely minimal" single VM, it might add unnecessary complexity and could be omitted initially.  
  * CONFIG\_DRM\_VIRTIO\_GPU: A VirtIO-based GPU for graphics acceleration.27 This is unlikely to be needed for a minimal server-side Elixir application that doesn't require a graphical interface.

The use of VirtIO drivers is practically non-negotiable for a performant minimal VM. Emulating older hardware (e.g., IDE controllers for disks, e1000 NICs for networking) is significantly slower and adds unnecessary emulation support code to the kernel. VirtIO is specifically designed for virtualization and drastically reduces I/O overhead. Therefore, the pursuit of a "minimal footprint" should not compromise essential VM performance; VirtIO drivers are a key enabler here.When configuring these drivers, a choice exists between building them directly into the kernel (y) or as loadable kernel modules (m). For an "absolutely minimal" system where the virtual hardware is known and fixed (as is typical in a QEMU VM setup for a specific purpose), compiling VirtIO drivers directly into the kernel is preferable. This approach avoids the overhead associated with the kernel's module loading infrastructure (including the size of the module files themselves and the initramfs complexity if modules are needed early in boot) and ensures that the necessary drivers are available immediately when the kernel starts.29 If drivers are compiled as modules (m), the initramfs might need to include them and have logic to load them, adding to its size and complexity.

### **4.2. Other VM-Related Kernel Optimizations**

Beyond VirtIO, other kernel configurations can help optimize for a virtualized environment:

* **Disable Unneeded Hardware Support:** A significant advantage of targeting a VM is the highly predictable and limited set of virtual hardware. This allows for aggressive removal of drivers for physical hardware components that will not be present in the QEMU configuration (e.g., drivers for specific sound cards, Wi-Fi adapters, most USB controllers beyond basic EHCI/XHCI if USB passthrough isn't used, infrared devices, etc.). This is a general principle of kernel minimization but is particularly effective in a VM context.  
* **Paravirtualization Options:**  
  * CONFIG\_PARAVIRT=y: Enables generic paravirtualization optimizations, allowing the kernel to be aware it's running in a virtualized environment and cooperate with the hypervisor.  
  * CONFIG\_KVM\_GUEST=y (if using KVM as the hypervisor): Enables specific optimizations for KVM guests, such as paravirtualized clock sources and other KVM-specific features.30  
* **Timer Frequency (CONFIG\_HZ):** The kernel timer interrupt frequency can influence system overhead and responsiveness. Lower frequencies (e.g., 100 Hz) can reduce CPU overhead from timer interrupts but might impact the granularity of scheduling and timeouts. Higher frequencies (e.g., 1000 Hz) offer finer granularity but increase overhead. The default (often 250 Hz or 1000 Hz) is usually a reasonable compromise, but for extreme minimality, investigating the impact of lower values could be considered, keeping in mind potential effects on real-time behavior if relevant to the Elixir application.  
* **Disable SWAP Support:** If the system is designed to run entirely from RAM (e.g., using an initramfs) and swapping to a disk is not desired or feasible, swap support can be disabled in the kernel (General setup \> General architecture-dependent options \> Enable swap set to n). This removes code related to swap management.

The VM environment simplifies hardware choices considerably compared to physical embedded systems with their diverse and often proprietary peripherals. This simplification is a boon for kernel minimization efforts.

**Table 2: Essential Kernel Configuration Options (Kconfig) for Minimal Elixir VM**

| Kconfig Symbol | Path in menuconfig | Purpose | Recommended Setting | Rationale for Minimal Elixir VM |
| :---- | :---- | :---- | :---- | :---- |
| CONFIG\_64BIT | Processor type and features | Enable 64-bit kernel | y | Better performance and address space for Elixir/BEAM; standard for modern VMs. |
| CONFIG\_EMBEDDED | General setup | Optimize for embedded systems (smaller data structures, etc.) | y | Aligns with minimality goal. |
| CONFIG\_EXPERT | General setup | Allow configuration of more advanced/dangerous options | y | Needed to access some fine-grained minimization options. |
| CONFIG\_TTY | Device Drivers \> Character devices | Enable TTY support | y | Essential for console interaction and debugging.1 |
| CONFIG\_VT\_CONSOLE | Device Drivers \> Character devices \> Virtual terminal | Enable virtual terminal on console | y | Needed for TTY functionality. |
| CONFIG\_SERIAL\_8250\_CONSOLE | Device Drivers \> Character devices \> Serial drivers | Console on 8250/16550 serial port | y | Common for QEMU serial console output. |
| CONFIG\_PRINTK | General setup \> Configure standard kernel features (expert users) | Enable kernel printk messages | y | Crucial for boot-time diagnostics.1 (Disable only if absolutely necessary and system is stable). |
| CONFIG\_BINFMT\_ELF | Executable file formats / Emulations | Support for ELF binaries | y | Required to run any user-space programs, including init and Elixir.1 |
| CONFIG\_BLK\_DEV\_INITRD | General setup \> Initial RAM filesystem and RAM disk (initramfs/initrd) support | Enable initramfs/initrd support | y | If using an initramfs for the root filesystem.1 |
| CONFIG\_RD\_GZIP | General setup \> Initial RAM filesystem and RAM disk (initramfs/initrd) support | Support for gzip-compressed initramfs | y | Common compression for initramfs. |
| CONFIG\_VIRTIO | Device Drivers \> Virtio drivers | Core VirtIO support | y | Essential for paravirtualized devices in VMs.27 |
| CONFIG\_VIRTIO\_PCI | Device Drivers \> Virtio drivers | VirtIO over PCI transport | y | Common transport for VirtIO devices in QEMU. |
| CONFIG\_VIRTIO\_BLK | Device Drivers \> Block devices | VirtIO block device driver | y | High-performance virtual disk access.27 |
| CONFIG\_VIRTIO\_NET | Device Drivers \> Network device support | VirtIO network device driver | y | High-performance virtual network access.29 |
| CONFIG\_VIRTIO\_CONSOLE | Device Drivers \> Character devices | VirtIO console driver | y | Efficient serial console for VM interaction.27 |
| CONFIG\_HW\_RANDOM\_VIRTIO | Device Drivers \> Character devices \> Hardware Random Number Generator core support | VirtIO Random Number Generator | y | Provides entropy from host to guest, useful for crypto.27 |
| CONFIG\_PARAVIRT | Processor type and features \> Paravirtualized guest support | Enable paravirtualization optimizations | y | General performance improvement in VMs. |
| CONFIG\_KVM\_GUEST | Processor type and features \> Paravirtualized guest support | Optimizations for KVM guests | y (if using KVM) | Specific enhancements when running under KVM hypervisor.30 |
| CONFIG\_PROC\_FS | File systems \> Pseudo filesystems | /proc filesystem support | y | Essential for many system utilities (e.g., ps, top) and system information. |
| CONFIG\_SYSFS | File systems \> Pseudo filesystems | /sys filesystem support | y | Provides interface to kernel objects and device information. |
| CONFIG\_DEVTMPFS | Device Drivers \> Generic Driver Options | Maintain a devtmpfs filesystem for dynamic /dev | y | Recommended for modern dynamic /dev management.8 |
| CONFIG\_DEVTMPFS\_MOUNT | Device Drivers \> Generic Driver Options | Automount devtmpfs at /dev after kernel mount | y | Simplifies setup by automatically mounting devtmpfs. |
| CONFIG\_NET | Networking support | Enable networking | y | Required for any network functionality, including VirtIO net. |
| CONFIG\_INET | Networking support \> Networking options | TCP/IP networking | y | Essential for most network applications, including those Elixir might use. |
| CONFIG\_UNIX | Networking support \> Networking options | Unix domain sockets | y | Used for local inter-process communication, BEAM may use this. |
| CONFIG\_PACKET | Networking support \> Networking options | Packet sockets | y (optional) | Needed for tools like tcpdump, some low-level network libraries. May not be strictly needed for all Elixir apps. |
| CONFIG\_NO\_HZ\_IDLE or CONFIG\_NO\_HZ\_FULL | Processor type and features \> Timer tick handling | Tickless system options | Consider (Advanced) | Can reduce timer interrupts on idle/busy CPUs, potentially saving power/overhead. Requires careful testing. |
| CONFIG\_HZ\_PERIODIC | Processor type and features \> Timer tick handling | Periodic timer ticks | y (default) | Simpler and more common than full tickless. |
| CONFIG\_HIGH\_RES\_TIMERS | Processor type and features \> Timer tick handling | High resolution timer support | y | Often beneficial for applications requiring precise timing, BEAM may benefit. |

## **5\. Integrating and Running Elixir Applications**

Once a minimal Linux kernel and root filesystem are established, the next crucial step is to integrate the Erlang/OTP runtime and the Elixir application itself.

### **5.1. Adding Erlang/OTP and Elixir to the Root Filesystem**

The responsibility for compiling Erlang/OTP and Elixir for the target architecture and installing them into the root filesystem primarily falls to the chosen build system (Buildroot, Yocto with meta-erlang, or Nerves). These systems manage the cross-compilation process and ensure that the necessary runtime components are placed in the staging directory, which subsequently forms part of the final rootfs image.

The key components from the Erlang/OTP and Elixir ecosystem that need to be present in the RFS for an Elixir application to run are:

* **Erlang Runtime System (ERTS):** This includes the core BEAM virtual machine files and essential runtime libraries.  
* **Standard Erlang libraries:** Crucial OTP applications like stdlib (standard library) and kernel (low-level OS interaction, process management) must be available.  
* **Elixir core libraries:** The fundamental Elixir libraries that provide the language's core functionality.  
* **The compiled Elixir application:** This is typically packaged as a Mix release.

Build systems usually install these components into standard locations within the RFS, such as /usr/lib/erlang/ and /usr/lib/elixir/, or sometimes under /opt/.

A critical aspect of this integration is ensuring that the versions of Erlang/OTP and Elixir are compatible. Elixir versions have specific Erlang/OTP version requirements.23 The package definitions within the build system (e.g.,

elixir.mk in Buildroot, or recipes in meta-erlang for Yocto) are designed to manage these dependencies. For instance, meta-erlang documentation often specifies supported version combinations of Erlang, Elixir, and Yocto releases.23 If undertaking heavy customization or manual integration, maintaining this compatibility is paramount.

### **5.2. Packaging Elixir Applications with Mix Releases**

Mix releases are the standard and recommended way to package a compiled Elixir application along with all its dependencies. A release can also bundle the necessary parts of the Erlang Runtime System (ERTS) to make it self-contained, though this aspect is nuanced when a build system already provides ERTS.2

* **Benefits for Embedded Systems:**  
  * **Self-contained Application Package:** The release bundles the application's compiled bytecode (.beam files) and all its Elixir and Erlang dependencies.  
  * **Code Preloading:** Releases typically run the BEAM in "embedded mode," which preloads all available application modules at startup. This contrasts with the "interactive mode" (default for iex), where modules are loaded on demand, potentially causing latency spikes for initial requests in a production system.34  
  * **Configuration Management:** Releases provide robust mechanisms for runtime configuration. This includes config/runtime.exs for Elixir-level configuration, and template files like rel/env.sh.eex (for setting environment variables) and rel/vm.args.eex (for configuring BEAM VM flags) that are processed when the release starts.34  
* Creating a Release:  
  A production release is typically created using the command MIX\_ENV=prod mix release.33 This process compiles the application and its dependencies, and assembles them into a structured directory.  
* Output Structure:  
  The output of mix release is usually found in \_build/\<MIX\_ENV\>/rel/\<app\_name\>/. This directory contains several subdirectories 33:  
  * bin/: Contains control scripts to start, stop, and manage the release. The main executable script is named after the application.  
  * lib/: Contains the compiled Elixir and Erlang code for the application and its dependencies.  
  * releases/: Contains metadata about the release, including version information and boot scripts.  
  * erts-VERSION/: May contain a copy of the Erlang Runtime System if the release is configured to bundle it.  
* Integrating into the RFS:  
  The chosen build system needs to be configured to incorporate the Elixir release into the target root filesystem. This typically involves two steps:  
  1. **Building the Elixir Release:** This can be done as part of the build system's packaging process for the Elixir application (e.g., in a custom .mk file in Buildroot or a recipe in Yocto).  
  2. **Copying the Release Directory:** The entire release directory (e.g., \_build/prod/rel/\<app\_name\>) must be copied into an appropriate location in the target RFS, such as /app or /opt/\<app\_name\>.

The "self-contained ERTS" aspect of Mix releases requires careful consideration in a custom-built Linux environment. While Mix releases *can* bundle ERTS, when using a build system like Buildroot, Yocto, or Nerves, ERTS is usually already compiled and installed as part of the base system image. In such cases, the Mix release primarily serves to package the Elixir application's compiled code and its specific dependencies. The key is to ensure that the ERTS version used by the Mix release tooling (if it attempts to manage ERTS versions) is consistent with, or ideally uses, the ERTS version provided by the system image. Nerves handles this integration seamlessly. For Buildroot or Yocto, the Elixir application package should be configured to use the system-provided ERTS to avoid duplication and potential version conflicts.

### **5.3. Starting and Managing the Elixir Application**

How the Elixir application is started and managed at boot depends on the init system used in the minimal Linux environment.

* Nerves Approach (erlinit):  
  Nerves employs a specialized, minimal init process called erlinit.24  
  erlinit is a small C program that typically runs as PID 1 (the first user-space process). Its responsibilities include setting up basic filesystems (like /proc, /sys, /dev), initializing essential environment variables, and then starting erl\_child\_setup. This, in turn, launches the BEAM. The main Elixir application, defined in its mix.exs file (usually as an OTP Application), is then started and supervised directly by the BEAM. This approach makes the BEAM the central supervisor for the Elixir application components.  
* Buildroot/Yocto with Traditional Init (e.g., BusyBox init):  
  If using a more traditional init system like the one provided by BusyBox, an init script is required to launch the Elixir application. This script would typically be placed in a directory like /etc/init.d/ (e.g., /etc/init.d/S99myapp, where S99 indicates its start order) or referenced by /etc/inittab if using BusyBox's sysvinit-compatible init.  
  This init script would be responsible for:  
  1. Setting any necessary environment variables required by the BEAM or the Elixir application (e.g., PATH, HOME, custom configuration variables).  
  2. Navigating to the directory where the Elixir release was installed in the RFS (e.g., cd /app).  
  3. Executing the release's start command, often found in its bin/ directory (e.g., /app/bin/\<app\_name\> start to run in the background as a daemon, or /app/bin/\<app\_name\> foreground to run in the foreground).33  
* Runtime Configuration:  
  Regardless of the startup method, Elixir applications packaged as releases leverage config/runtime.exs for runtime configuration. This file is evaluated when the release starts, allowing access to environment variables (via System.get\_env/1) or other external configuration sources.34 Additionally, the  
  rel/env.sh.eex and rel/vm.args.eex template files within the release structure allow for customization of environment variables passed to the BEAM and the VM's command-line arguments, respectively.34

The choice of init system fundamentally impacts how the Elixir application is launched and managed. Nerves' erlinit is highly tailored for making the BEAM the heart of the system, which is very efficient for Elixir-first devices. With BusyBox init, the Elixir application behaves more like a traditional daemonized service within a more general-purpose (though minimal) Linux environment. The latter offers more familiar Linux service management paradigms but might introduce slightly more process overhead if the BEAM is intended to be the primary supervisory entity. For an "absolutely minimal" system where Elixir is the main workload, an erlinit-like approach offers a very lean and efficient startup path.

## **6\. Deployment: Building and Booting in a QEMU VM**

Once the minimal Linux system with Elixir support is configured and built, the final steps involve generating bootable images and launching them in a QEMU virtual machine for testing and deployment.

### **6.1. Generating Bootable Images**

The build process will produce several artifacts, including the kernel image and the root filesystem in a suitable format.

* Kernel Image:  
  The compiled Linux kernel is typically a file named bzImage (for x86 architectures) or a similar architecture-specific name (e.g., zImage, Image). After a manual kernel compilation, this file is found in the arch/\<architecture\>/boot/ directory within the kernel source tree.1 If using a build system like Buildroot, the kernel image will be placed in its output directory, commonly  
  output/images/.12  
* Root Filesystem Image:  
  The format of the root filesystem image depends on the chosen boot strategy:  
  * **initramfs.cpio.gz:** For systems where the root filesystem is loaded entirely into RAM, an initramfs is used. This is a CPIO archive of the RFS, usually compressed with gzip.1 It can be created manually using a command sequence like  
    find. \-print0 | cpio \--null \-o \-H newc | gzip \--best \>../initrd.gz from within the RFS directory 4, or generated automatically by build systems like Buildroot.  
  * **Raw Disk Image (.img):** For systems requiring persistent storage for the root filesystem, a raw disk image is a common choice.  
    1. **Creation:** An empty raw disk image can be created using qemu-img create myimage.img \<size\> (e.g., qemu-img create rootfs.img 512M).36  
    2. **Population:** To populate this image, it typically needs to be associated with a loop device (losetup), partitioned (optional, but common for bootloader compatibility), formatted with a filesystem (e.g., ext4 using mkfs.ext4), mounted, and then the contents of the RFS (from the build system's output/target/ directory, for example) are copied into it. If not using QEMU's direct kernel boot feature, a bootloader (like GRUB) would also need to be installed onto this disk image. Procedures for creating an ext4 image from Buildroot output are described in sources like.8  
* Build System Output:  
  Comprehensive build systems like Buildroot, Yocto, and Nerves typically automate the generation of these bootable images and place them in a designated output directory (e.g., output/images/ for Buildroot 11). Nerves, for instance, produces  
  .fw firmware files, which are essentially packaged images containing the kernel, RFS, and other necessary components for deployment to target hardware or use with emulators.

For a VM scenario aiming for "absolutely minimal" footprint, especially if the root filesystem itself does not require persistence (application data can be stored on separate virtual disks if needed), using an initramfs is generally more "minimal." It avoids the overhead of disk partition tables, filesystem metadata on a block device, and potentially the need for a bootloader within the image if QEMU's direct kernel loading capability is utilized.

### **6.2. Essential QEMU Command-Line Options**

QEMU offers a vast array of command-line options to configure the virtual machine. For booting a custom minimal Linux system, several are particularly important:

* Basic Invocation:  
  The command typically starts with qemu-system-x86\_64 (for an x86-64 guest) or the equivalent for other architectures (e.g., qemu-system-aarch64).1  
* Direct Kernel Boot (with initramfs):  
  This is often the most straightforward method for minimal systems:  
  * \-kernel \<path\_to\_bzImage\>: Specifies the path to the compiled kernel image.1  
  * \-initrd \<path\_to\_initramfs.cpio.gz\>: Specifies the path to the initramfs archive.1  
  * \-append "\<kernel\_command\_line\_options\>": Passes arguments to the Linux kernel during boot.1 Common and essential arguments include:  
    * root=/dev/ram0: Tells the kernel to use the RAM disk (loaded via \-initrd) as the root filesystem.  
    * init=/bin/sh or init=/sbin/init: Specifies the first user-space process to execute. For very minimal systems or initial testing, /bin/sh (from BusyBox) can be used directly. For a more structured boot, /sbin/init (also typically from BusyBox) is used.1  
    * console=ttyS0: Directs the kernel's console output to the first serial port (ttyS0), which QEMU makes accessible, usually on the terminal where QEMU was launched if \-nographic is used.38  
    * quiet: Reduces the verbosity of kernel boot messages.  
* **Booting from a Raw Disk Image:**  
  * \-drive file=\<path\_to\_raw\_image.img\>,format=raw,index=0,media=disk: Attaches the raw disk image as the primary hard drive.38  
  * When booting from a disk image, the image must contain a bootloader (e.g., GRUB) that is capable of loading the kernel, unless QEMU's firmware/BIOS can directly locate and load a kernel from a known partition/path (less common for highly custom setups). For simplicity with a custom minimal kernel, direct kernel boot (-kernel) is often preferred even if a small disk image is used for other purposes.  
* **VM Configuration:**  
  * \-m \<memory\_size\>: Sets the amount of RAM allocated to the VM (e.g., \-m 256M or \-m 1G). While a tiny kernel with a BusyBox shell was found to boot in as little as 29MB of RAM 1, an Elixir application running on the BEAM will require significantly more, likely in the range of hundreds of megabytes, depending on the application's complexity.  
  * \-nographic: Disables QEMU's graphical output window and redirects the virtual serial port and QEMU monitor to the console from which QEMU was launched.38 This is highly useful for server applications or headless systems.  
  * \-cpu host or a specific CPU model (e.g., \-cpu Nehalem): Passing through host CPU features (-cpu host) can improve performance. Specifying a model ensures consistent CPU features across different host machines if portability is a concern.  
  * Network Configuration: To enable networking with VirtIO:  
    \-netdev user,id=net0 \-device virtio-net-pci,netdev=net0  
    This sets up user-mode networking (allowing the VM to access the host's network via NAT) and attaches a VirtIO PCI network device.  
* Buildroot QEMU Script:  
  Buildroot often generates a convenient shell script named start-qemu.sh in its output/images/ directory. This script contains a pre-configured QEMU command line tailored to the system that Buildroot has just built, providing a quick way to boot and test the image.11

QEMU's direct kernel loading capability, using the \-kernel and \-initrd options, is generally the most straightforward and "minimal" path for booting a highly customized kernel and an initramfs-based root filesystem. This approach bypasses the need to install, configure, and include a bootloader like GRUB within the initramfs or on a disk image, thereby reducing both complexity and the final image size. This aligns perfectly with the goal of an "absolutely minimal" system.

## **7\. Recommendations and Advanced Optimization**

Choosing the optimal path and fine-tuning the system for absolute minimality requires careful consideration of project goals, available resources, and the trade-offs involved.

### **7.1. Guidance on Selecting the Most Suitable Approach**

Recapping the strengths of the discussed build systems in the context of a minimal Elixir VM:

* **Nerves Project:** Offers the most Elixir-centric experience. It is ideal for projects where Elixir is the primary focus, ease of use and rapid development are paramount, and its baseline image size (around 20-30 MB including BEAM) is acceptable. The availability of a generic nerves\_system\_x86\_64 makes it suitable for VM targets.24  
* **Buildroot:** Provides excellent control for creating a truly minimal underlying Linux base. It is the best choice if the goal is to achieve the smallest possible non-Elixir footprint and then add Elixir/BEAM as a component, or if deep customization of the base OS is required. It demands more manual effort for Elixir integration compared to Nerves.  
* **Yocto Project:** Generally an overkill for the specific query of a single minimal Elixir VM. Its strengths lie in managing complex product lines with diverse hardware and software requirements. While possible to create minimal systems (e.g., with Poky-Tiny 7), the learning curve and complexity are substantial.

The decision hinges on several factors:

* **Primary Goal:** If the objective is "get Elixir running in a tiny Linux VM as quickly and easily as possible," Nerves is a very strong contender. If the objective is "craft the smallest conceivable Linux system that *can* run Elixir, with full control over every component," Buildroot offers more direct pathways to that level of minimality for the base OS.  
* **Team Expertise:** Teams with strong Elixir skills but perhaps less deep embedded Linux internals experience may find Nerves more approachable. Teams with robust embedded Linux and kernel customization skills will be comfortable with Buildroot.  
* **Time to First Bootable Image:** Nerves is likely to provide the fastest route to a bootable Elixir application. Building a minimal Linux system from scratch with Buildroot and then integrating Elixir will take more time initially.  
* **Tolerance for Abstraction:** Nerves provides significant abstraction over the underlying Buildroot system. Buildroot offers a more direct, less abstracted interface to the build process.

The virtual machine context somewhat lowers the barrier to entry for Nerves. Nerves' primary strength has historically been abstracting the complexities of diverse physical embedded hardware. In a VM, the "hardware" is standardized by QEMU's virtual devices (ideally VirtIO). This makes Nerves' nerves\_system\_x86\_64 24 a good and readily available fit, potentially reducing the need for the deep, hardware-specific Buildroot customizations that might be required when targeting unique physical embedded boards.

### **7.2. Advanced Tips for Further Footprint Reduction**

Once a basic minimal system is booting and running the Elixir application, further optimizations can be pursued to shave off additional kilobytes or megabytes:

* **C Library Choice:** Re-emphasize the potential of musl libc for its small size and good static linking capabilities, if full compatibility with the BEAM and any NIFs can be ensured through testing.7  
* **Kernel Configuration Revisited:** After the system is stable and functional, iteratively review the kernel configuration (.config file) and disable more features or drivers that are confirmed to be unused in the specific VM environment. Tools like make localmodconfig (which tailors a config based on currently loaded modules on a running system) can provide hints, but careful manual review and testing are essential for a truly minimal custom kernel.  
* **BusyBox Applet Selection:** Be ruthless in deselecting any BusyBox applets that are not strictly required by the init scripts or for essential debugging/maintenance. Every unselected applet reduces the size of the BusyBox binary.  
* **Stripping Binaries:** Ensure that all executable files and shared libraries in the final root filesystem are stripped of debugging symbols and other unnecessary sections. This is typically done using the strip utility from the cross-compile toolchain. Most build systems (Buildroot, Yocto, Nerves) perform this step automatically for release builds.  
* **Remove Development Files:** Double-check that no development headers (.h files), static libraries (.a files), or other development-specific artifacts end up in the final root filesystem image. Build systems are generally good at preventing this, but manual verification is worthwhile.  
* **Compressing Root Filesystem:** If using an initramfs, experiment with different compression levels and algorithms. gzip \--best provides good compression. xz generally offers even better compression ratios but at the cost of slower decompression times during boot. The trade-off depends on whether boot speed or absolute image size is more critical.  
* **Erlang/OTP Application Stripping:** Modern versions of Erlang/OTP (OTP 20 and later) include features that allow for "stripping" unused modules from OTP applications during the release process. This can potentially reduce the on-disk size of the Erlang/OTP installation and the Elixir application's dependencies. Mix release tools often leverage these capabilities.

It is important to recognize that minimization is often a game of diminishing returns and increasing risk. The initial big wins in size reduction come from choosing a minimal base (e.g., tinyconfig for the kernel, BusyBox for utilities, a lightweight C library like musl). Subsequent, more aggressive optimizations (e.g., stripping every possible byte, removing obscure kernel features without full certainty of their non-use) tend to save progressively fewer bytes while increasing the risk of breaking functionality or making the system significantly harder to debug. A pragmatic balance must be struck between achieving the desired minimality and maintaining a robust, functional, and maintainable system.

## **8\. Conclusion**

### **8.1. Recap of Viable Pathways**

Creating a Linux kernel with an absolutely minimal footprint in a VM that supports Elixir execution is a multifaceted task achievable through several viable pathways. The Nerves Project offers the most integrated and Elixir-centric approach, abstracting much of the underlying system complexity and providing a quick route to a functional, albeit moderately sized (20-30MB), Elixir system. Buildroot stands out for those seeking maximum control and the smallest possible non-Elixir base, upon which Elixir/BEAM can be carefully integrated. The Yocto Project, while highly capable, generally presents more complexity than is warranted for this specific goal unless broader project requirements dictate its use. Regardless of the chosen build system, the core strategies involve aggressive kernel customization starting from a tinyconfig baseline, construction of a minimal root filesystem using BusyBox and a lightweight C library, and meticulous configuration of VirtIO drivers for optimal VM performance. The key realization is that achieving an "absolutely minimal" footprint for an Elixir system means minimizing the Linux infrastructure *around* the inherently non-trivial BEAM runtime.

### **8.2. Final Thoughts on Balancing Minimality with Functionality and Development Effort**

The "perfect" solution is contingent upon the precise interpretation of requirements—particularly the definition of "minimal"—and the broader project context, including team expertise and development timelines. There is an inherent trade-off between the degree of minimality achieved, the functionality retained, and the engineering effort invested. Pushing for extreme minimality can lead to a brittle system that is difficult to debug or extend.

An iterative approach is often most effective: begin by establishing a working, bootable system that runs the Elixir application, even if it's not yet fully minimized. Once functionality is confirmed, progressive optimization for size can be undertaken, layer by layer. This allows for controlled refinement and reduces the risk of creating an unusable system. The journey to a minimal Elixir VM is ultimately an exercise in understanding and meticulously managing system dependencies, from the lowest levels of hardware abstraction provided by the VM up through the kernel, C library, Erlang/OTP runtime, and finally, the Elixir application itself. Success lies in providing just enough of a system to satisfy these dependencies efficiently and robustly.

#### **Works cited**

1. Building a tiny Linux kernel \- Anuradha Weeraman, accessed June 11, 2025, [https://weeraman.com/building-a-tiny-linux-kernel/](https://weeraman.com/building-a-tiny-linux-kernel/)  
2. Nerves Project, accessed June 11, 2025, [https://nerves-project.org/](https://nerves-project.org/)  
3. Nerves: buildroot linux and Erlang, with an Erlang "init" \- Hacker News, accessed June 11, 2025, [https://news.ycombinator.com/item?id=11830413](https://news.ycombinator.com/item?id=11830413)  
4. Building a tiny Linux from scratch, accessed June 11, 2025, [https://blinry.org/tiny-linux/](https://blinry.org/tiny-linux/)  
5. Building a Tiny Linux Kernel \#linux \#linuxfromscratch \#linuxhacking \#kernel \#kernelspace, accessed June 11, 2025, [https://www.youtube.com/watch?v=ruAPv21aY9A](https://www.youtube.com/watch?v=ruAPv21aY9A)  
6. booting a fresh linux kernel on qemu \- ops.tips, accessed June 11, 2025, [https://ops.tips/notes/booting-linux-on-qemu/](https://ops.tips/notes/booting-linux-on-qemu/)  
7. The smallest ... \- Thoughts dereferenced from the scratchpad noise., accessed June 11, 2025, [https://blog.3mdeb.com/2019/2019-06-26-smallest-embedded-system-yocto-vs-buildroot/](https://blog.3mdeb.com/2019/2019-06-26-smallest-embedded-system-yocto-vs-buildroot/)  
8. buildroot – Gateworks, accessed June 11, 2025, [https://trac.gateworks.com/wiki/buildroot](https://trac.gateworks.com/wiki/buildroot)  
9. Building the Minimal Rootfs Using Busybox \- Embedded learning, accessed June 11, 2025, [https://embeddedstudy.home.blog/2019/01/23/building-the-minimal-rootfs-using-busybox/](https://embeddedstudy.home.blog/2019/01/23/building-the-minimal-rootfs-using-busybox/)  
10. Building a Root File System using BusyBox \- Emreboy \- WordPress.com, accessed June 11, 2025, [https://emreboy.wordpress.com/2012/12/20/building-a-root-file-system-using-busybox/](https://emreboy.wordpress.com/2012/12/20/building-a-root-file-system-using-busybox/)  
11. The First Steps With Buildroot \- ejaaskel, accessed June 11, 2025, [https://ejaaskel.dev/the-first-steps-with-buildroot/](https://ejaaskel.dev/the-first-steps-with-buildroot/)  
12. Build a Simple Linux Kernel Using Buildroot \- DEV Community, accessed June 11, 2025, [https://dev.to/devdoesit17/build-a-simple-linux-kernel-using-buildroot-4d29](https://dev.to/devdoesit17/build-a-simple-linux-kernel-using-buildroot-4d29)  
13. Deciding between Buildroot & Yocto \- LWN.net, accessed June 11, 2025, [https://lwn.net/Articles/682540/](https://lwn.net/Articles/682540/)  
14. Buildroot \- Hacker News, accessed June 11, 2025, [https://news.ycombinator.com/item?id=41752989](https://news.ycombinator.com/item?id=41752989)  
15. package/elixir/elixir.mk · 2020.08.x · undefined \- GitLab, accessed June 11, 2025, [https://git.esiee.fr/leblona/buildroot-project/-/blob/2020.08.x/package/elixir/elixir.mk](https://git.esiee.fr/leblona/buildroot-project/-/blob/2020.08.x/package/elixir/elixir.mk)  
16. package/elixir · 2020.08.x · Alexandre LEBLON / Buildroot Project \- GitLab, accessed June 11, 2025, [https://git.esiee.fr/leblona/buildroot-project/-/tree/2020.08.x/package/elixir](https://git.esiee.fr/leblona/buildroot-project/-/tree/2020.08.x/package/elixir)  
17. cogini/buildroot\_elixir \- GitHub, accessed June 11, 2025, [https://github.com/cogini/buildroot\_elixir](https://github.com/cogini/buildroot_elixir)  
18. customize-rootfs.txt \- Buildroot, accessed June 11, 2025, [https://buildroot.org/downloads/manual/customize-rootfs.txt](https://buildroot.org/downloads/manual/customize-rootfs.txt)  
19. Yocto vs. Buildroot: Detailed Comparison For Beginners \- Epteck GmbH, accessed June 11, 2025, [https://epteck.com/yocto-vs-buildroot-comparison/](https://epteck.com/yocto-vs-buildroot-comparison/)  
20. Yocto or Buildroot : r/embedded \- Reddit, accessed June 11, 2025, [https://www.reddit.com/r/embedded/comments/1ga7tdw/yocto\_or\_buildroot/](https://www.reddit.com/r/embedded/comments/1ga7tdw/yocto_or_buildroot/)  
21. "Introduction to the Yocto Project and Bitbake, Part 1" by Behan Webster \- YouTube, accessed June 11, 2025, [https://www.youtube.com/watch?v=yuE7my3KOpo](https://www.youtube.com/watch?v=yuE7my3KOpo)  
22. Introduction | meta-erlang, accessed June 11, 2025, [https://meta-erlang.github.io/docs/nanbield/](https://meta-erlang.github.io/docs/nanbield/)  
23. githubproxy/meta-erlang \- Gitee, accessed June 11, 2025, [https://gitee.com/github\_proxy/meta-erlang](https://gitee.com/github_proxy/meta-erlang)  
24. nerves-project/nerves: Craft and deploy bulletproof embedded software in Elixir \- GitHub, accessed June 11, 2025, [https://github.com/nerves-project/nerves](https://github.com/nerves-project/nerves)  
25. Anatomy of Embedded Elixir \- Underjord, accessed June 11, 2025, [https://underjord.io/anatomy-of-embedded-elixir.html](https://underjord.io/anatomy-of-embedded-elixir.html)  
26. Virtio on Linux \- The Linux Kernel documentation, accessed June 11, 2025, [https://docs.kernel.org/driver-api/virtio/virtio.html](https://docs.kernel.org/driver-api/virtio/virtio.html)  
27. Building a kernel with the virtio CCW transport device driver \- IBM, accessed June 11, 2025, [https://www.ibm.com/docs/en/linux-on-systems?topic=ccw-building-kernel](https://www.ibm.com/docs/en/linux-on-systems?topic=ccw-building-kernel)  
28. config\_virtio\_blk \- kernelconfig.io, accessed June 11, 2025, [https://www.kernelconfig.io/config\_virtio\_blk](https://www.kernelconfig.io/config_virtio_blk)  
29. Install the virtio driver in a Linux operating system \- Elastic Compute Service \- Alibaba Cloud Documentation Center, accessed June 11, 2025, [https://www.alibabacloud.com/help/en/ecs/user-guide/install-the-virtio-driver](https://www.alibabacloud.com/help/en/ecs/user-guide/install-the-virtio-driver)  
30. Kingsoft Cloud-Documentation-How can I install a virtio driver (Linux)?, accessed June 11, 2025, [https://endocs.ksyun.com/documents/5425?type=3](https://endocs.ksyun.com/documents/5425?type=3)  
31. linux/linux-stable.git \- Linux kernel stable tree, accessed June 11, 2025, [https://git.sceen.net/linux/linux-stable.git/log/drivers/block/virtio\_blk.c?h=v4.9.198\&id=667be1e757f5684576d01d7402907a2489b1402f](https://git.sceen.net/linux/linux-stable.git/log/drivers/block/virtio_blk.c?h=v4.9.198&id=667be1e757f5684576d01d7402907a2489b1402f)  
32. Install \- The Elixir programming language, accessed June 11, 2025, [https://elixir-lang.org/install.html](https://elixir-lang.org/install.html)  
33. Distillery (Basics) \- Elixir School, accessed June 11, 2025, [https://elixirschool.com/en/lessons/misc/distillery](https://elixirschool.com/en/lessons/misc/distillery)  
34. Configuration and releases — Elixir v1.18.4 \- HexDocs, accessed June 11, 2025, [https://hexdocs.pm/elixir/config-and-releases.html](https://hexdocs.pm/elixir/config-and-releases.html)  
35. mix release — Mix v1.18.4 \- HexDocs, accessed June 11, 2025, [https://hexdocs.pm/mix/Mix.Tasks.Release.html](https://hexdocs.pm/mix/Mix.Tasks.Release.html)  
36. Disk Images — QEMU documentation, accessed June 11, 2025, [https://qemu-project.gitlab.io/qemu/system/images.html](https://qemu-project.gitlab.io/qemu/system/images.html)  
37. Create a Raw Disk Image | QEMU QED \- GitLab, accessed June 11, 2025, [https://eaasi.gitlab.io/program\_docs/qemu-qed/usage/create\_raw\_disk\_image/](https://eaasi.gitlab.io/program_docs/qemu-qed/usage/create_raw_disk_image/)  
38. Direct Linux Boot — QEMU documentation, accessed June 11, 2025, [https://qemu-project.gitlab.io/qemu/system/linuxboot.html](https://qemu-project.gitlab.io/qemu/system/linuxboot.html)  
39. Running QEMU with a root file system directory instead of disk image, accessed June 11, 2025, [https://unix.stackexchange.com/questions/406051/running-qemu-with-a-root-file-system-directory-instead-of-disk-image](https://unix.stackexchange.com/questions/406051/running-qemu-with-a-root-file-system-directory-instead-of-disk-image)  
40. Problems with booting a raw image with QEMU \- Help Needed : r/qemu\_kvm \- Reddit, accessed June 11, 2025, [https://www.reddit.com/r/qemu\_kvm/comments/j1cuv2/problems\_with\_booting\_a\_raw\_image\_with\_qemu\_help/](https://www.reddit.com/r/qemu_kvm/comments/j1cuv2/problems_with_booting_a_raw_image_with_qemu_help/)  
41. Booting from a Hard Disk Image | QEMU QED \- GitLab, accessed June 11, 2025, [https://eaasi.gitlab.io/program\_docs/qemu-qed/usage/booting\_hard\_disk/](https://eaasi.gitlab.io/program_docs/qemu-qed/usage/booting_hard_disk/)