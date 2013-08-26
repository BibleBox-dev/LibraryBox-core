NAME = librarybox
VERSION = 2.0.0_alpha8
ARCH = all

#PIRATEBOX_IMG_URL = "http://piratebox.aod-rpg.de/piratebox_ws_0.6_img.gz"

# Data Folder from
SRC_FOLDER=piratebox_origin
SRC_SCRIPT_LOCATION=$(SRC_FOLDER)/piratebox/piratebox
SRC_VERSION_TAG=$(SRC_SCRIPT_LOCATION)/version


BUILD_FOLDER=build_dir
BUILD_SCRIPT_LOCATION=$(BUILD_FOLDER)/piratebox

IMAGE_BUILD=tmp_img
IMAGE_BUILD_SRC=$(IMAGE_BUILD)/src
IMAGE_BUILD_TGT=$(IMAGE_BUILD)/tgt

MOD_SRC_FOLDER=customization
MOD_VERSION_TAG=$(BUILD_SCRIPT_LOCATION)/version_tag_mod

# Filename requested by 
MOD_IMAGE=$(IMAGE_BUILD)/OpenWRT_image
MOD_IMAGE_TGZ=$(NAME)_2.0_img.tar.gz


#------------
PACKAGE_FOLDER=$(NAME)
MOD_PACKAGE_TGZ=$(NAME)_$(VERSION).tar.gz

#.DEFAULT_GOAL:
#.PHONY: 

#--------------------------------------------
$(MOD_FOLDER) $(BUILD_FOLDER) $(MOUNT_POINT) $(IMAGE_BUILD_SRC) $(IMAGE_BUILD_TGT) $(PACKAGE_FOLDER): 
	mkdir -p $@


#-------------------------------------------
# Build 

$(MOD_VERSION_TAG): 
	echo  "$(NAME) - $(VERSION)"   > $@

$(SRC_VERSION_TAG):
	cd $(SRC_FOLDER) && make

# Create version tags
# copy over stuff
prepare_build:  $(BUILD_FOLDER) $(SRC_VERSION_TAG) $(BUILD_SCRIPT_LOCATION)
#	cp -vr $(SRC_SCRIPT_LOCATION) $(BUILD_SCRIPT_LOCATION)  


$(BUILD_SCRIPT_LOCATION): $(SRC_VERSION_TAG)
	mkdir -p $@
	cp -vr $(SRC_SCRIPT_LOCATION)/*  $(BUILD_SCRIPT_LOCATION)
	cp -vr $(MOD_SRC_FOLDER)/*  $(BUILD_SCRIPT_LOCATION)

# Changing of configuration files only via differences
define ReconfigureConfig
	sed 's:HOST="piratebox.lan":HOST="librarybox.lan":'  -i  $(1)/piratebox.conf
	sed 's:DROOPY_ENABLED="yes":DROOPY_ENABLED="no":'  -i  $(1)/piratebox.conf
	sed 's:ssid=PirateBox - Share Freely:ssid=LibraryBox - Free Content!:' -i $(1)/hostapd.conf
	echo 'include "/opt/piratebox/conf/lighttpd/fastcgi.conf"' >> $(1)/lighttpd/lighttpd.conf
	echo 'include "/opt/piratebox/conf/lighttpd/custom_index.conf"' >> $(1)/lighttpd/lighttpd.conf
endef


$(BUILD_FOLDER)/customization_done: 
	$(call ReconfigureConfig,$(BUILD_SCRIPT_LOCATION)/conf)	
	touch $@

building: $(BUILD_SCRIPT_LOCATION) $(BUILD_FOLDER)/customization_done


#--------------------------------------------
# Preparing image

#Some additional preparations for OpenWRT images.
#  - run prepar


prepare_image_config: $(IMAGE_BUILD_SRC)  $(IMAGE_BUILD_TGT)
	cd  $(SRC_FOLDER) && make image_stuff/openwrt/conf
	cp -rv  $(SRC_FOLDER)/image_stuff/openwrt/* $(IMAGE_BUILD_SRC)
	
# We need to apply our custom configuration again, because we are copy them over from the origin again
#   I'm doin it this way, because the origin image knows what to change.
apply_custom_config:
	cp -v $(BUILD_SCRIPT_LOCATION)/conf/hook_custom.conf $(IMAGE_BUILD_SRC)/conf
	$(call ReconfigureConfig,$(IMAGE_BUILD_SRC)/conf)

$(MOD_IMAGE):
	gunzip -dc  $(SRC_FOLDER)/image_stuff/OpenWRT.img.gz > $@


$(MOD_IMAGE_TGZ): $(IMAGE_BUILD_TGT) $(MOD_IMAGE) $(MOD_VERSION_TAG) 
	echo "#### Mounting image-file"
	sudo  mount -o loop,rw,sync   $(MOD_IMAGE)   $(IMAGE_BUILD_TGT)
	echo "#### Copy over normal content"
	sudo   cp -vr $(BUILD_SCRIPT_LOCATION)/* $(IMAGE_BUILD_TGT)
	echo "#### Copy Modifications to image file"
	sudo   cp -vr $(MOD_SRC_FOLDER)/*   $(IMAGE_BUILD_TGT)
	sudo   cp -vr $(IMAGE_BUILD_SRC)/*   $(IMAGE_BUILD_TGT)
	sudo umount  $(IMAGE_BUILD_TGT)
	tar czf  $(MOD_IMAGE_TGZ)  $(MOD_IMAGE)

image: clean_image building prepare_image_config apply_custom_config $(MOD_IMAGE_TGZ) 

#---------------------------------------------
# Package creation

$(MOD_PACKAGE_TGZ): prepare_build building $(PACKAGE_FOLDER)
	cp -r  $(BUILD_FOLDER)/* 	$(PACKAGE_FOLDER)
	# Here for example tiny howtos or additional scripts
	tar czf $@  $(PACKAGE_FOLDER)
	


#---------------------------------------------
# Clean stuff

clean_image:
	- rm  $(MOD_IMAGE)

cleanall: clean 
	- rm -v $(MOD_IMAGE_TGZ)
	- rm -v $(MOD_PACKAGE_TGZ)
	- cd piratebox_origin && make clean

clean: 
	- rm -rvf $(PACKAGE_FOLDER)
	- rm -rvf $(BUILD_FOLDER)
	- rm -rvf $(IMAGE_BUILD)

#-------------------------------------------
# Bundle targets

all: image package

#comp....
shortimage: image

package: $(MOD_PACKAGE_TGZ)


