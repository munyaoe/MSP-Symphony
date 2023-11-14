package se.havochvatten.symphony.mapper;

import se.havochvatten.symphony.dto.MetadataPropertyDto;
import se.havochvatten.symphony.dto.MetadataSymphonyThemeDto;
import se.havochvatten.symphony.entity.SymphonyBand;
import se.havochvatten.symphony.entity.Metadata;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class EntityToMetadataDtoMapper {
    public static MetadataSymphonyThemeDto mapEntitiesToMetaDataThemeDto(String symphonyTheme,
                                                                         List<SymphonyBand> bandList,
                                                                         List<Metadata> metadataList) {
        MetadataSymphonyThemeDto symphonyThemeDto = new MetadataSymphonyThemeDto();
        symphonyThemeDto.setSymphonyThemeName(symphonyTheme);
        symphonyThemeDto.setProperties(new ArrayList<>());
        for (SymphonyBand band : bandList) {

            MetadataPropertyDto dto = mapEntityToPropertyDto(band);
            symphonyThemeDto.getProperties().add(dto);
        }
        return symphonyThemeDto;
    }

    private static MetadataPropertyDto mapEntityToPropertyDto(SymphonyBand band) {

        // List of "non-dynamic" properties to exclude from the "meta" map in
        // the dto. Since we utilize reflection to access all getters in the
        // entity, "Class" (getClass, by inheritance) needs to be excluded here
        // as well.
        String[] topLevelProperties = {"Class", "Id", "Title", "TitleLocal", "BandNumber", "BaselineVersion",
                                       "EcoSensitivities", "PressureSensitivities",
                                       "SymphonyThemeName", "SymphonyThemeLocal"};



        MetadataPropertyDto dto = new MetadataPropertyDto();
        dto.setId(band.getId());


        dto.setDefaultSelected(band.isDefaultSelected());
        dto.setBandNumber(band.getBandNumber());

        Method[] metaPropertyGetters = Arrays.stream(Metadata.class.getMethods()).filter(m -> {
            String methodName = m.getName();
            if (methodName.startsWith("get") && !Arrays.asList(topLevelProperties).contains(methodName.substring(3))) {
                return true;
            }
            return false;
        }).toArray(Method[]::new);

        for (Method m : metaPropertyGetters) {
            try {
                String value = (String) m.invoke(band);
                String property = m.getName().substring(3);
                if (value != null && !value.equals("")) {
                    dto.getMeta().put(Character.toLowerCase(property.charAt(0)) + property.substring(1), value);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        return dto;
    }

}
